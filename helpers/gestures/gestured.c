// Touchpad swipe gestures for JellyFace. COSMIC keeps every swipe of 3+ fingers to itself (and does nothing with the
// 3-finger ones, nor with 4-finger swipes across the workspace axis), so they never reach Wayland clients. This reads
// the touchpad's evdev device directly, next to the compositor (not grabbed: COSMIC still sees everything), and sends
// these lines to the shell's socket (one connection, reopened when the shell restarts):
//     begin <fingers>                   3+ fingers touched
//     update <fingers> <dx> <dy>        travel so far in mm (dy < 0 = up), once per touchpad frame
//     swipe <fingers> up|down|left|right  the swipe is clear (once per touch, while the fingers are still down)
//     end <fingers> <dx> <dy>           all fingers lifted
//     cancel <fingers>                  the finger count changed (not this gesture after all) Needs read access to /dev/input (the "input" group).
// Usage: gestured [socket | --probe]   (default $XDG_RUNTIME_DIR/jellyface-gestures.sock). Exits 3 when no touchpad is readable.
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <math.h>
#include <poll.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

#define NSLOTS 10
#define BIT(arr, n) ((arr[(n) / 8] >> ((n) % 8)) & 1)

static char sock_path[108];
static int fd = -1;
static double unit_x = 1, unit_y = 1;  // device units per mm

// One connection to the shell, (re)opened at the start of each gesture: the shell may restart at any time.
// Writes never block: if the shell falls behind, a frame of movement is dropped rather than delaying the touchpad.
static int conn = -1;
static void send_line(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
static void send_line(const char *fmt, ...) {
    char line[96];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(line, sizeof line, fmt, ap);
    va_end(ap);
    if (conn < 0) return;
    if (send(conn, line, n, MSG_DONTWAIT | MSG_NOSIGNAL) < 0 && errno != EAGAIN) { close(conn); conn = -1; }
}
static void ensure_conn(void) {
    if (conn >= 0) {  // still open? (the shell closing its end shows up as readable + EOF)
        struct pollfd p = { conn, POLLIN, 0 };
        if (poll(&p, 1, 0) == 0) return;
        close(conn);
    }
    conn = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    struct sockaddr_un a = { .sun_family = AF_UNIX };
    memcpy(a.sun_path, sock_path, sizeof a.sun_path);
    if (conn >= 0 && connect(conn, (struct sockaddr *)&a, sizeof a) < 0) { close(conn); conn = -1; }
}

static double per_mm(int dev, int code) {
    struct input_absinfo ai;
    if (ioctl(dev, EVIOCGABS(code), &ai) < 0) return 1;
    if (ai.resolution > 0) return ai.resolution;
    return (ai.maximum - ai.minimum) / 100.0 > 0 ? (ai.maximum - ai.minimum) / 100.0 : 1;  // unknown: assume ~100 mm wide
}

// A touchpad: multitouch positions, reports 3 fingers, and is a pointer device (not a touchscreen)
static int open_touchpad(int *denied) {
    DIR *d = opendir("/dev/input");
    if (!d) return -1;
    struct dirent *e;
    int found = -1;
    while (found < 0 && (e = readdir(d))) {
        if (strncmp(e->d_name, "event", 5)) continue;
        char p[300];
        snprintf(p, sizeof p, "/dev/input/%s", e->d_name);
        int f = open(p, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (f < 0) { if (errno == EACCES) *denied = 1; continue; }
        unsigned char abs[ABS_MAX / 8 + 1] = {0}, key[KEY_MAX / 8 + 1] = {0}, prop[INPUT_PROP_MAX / 8 + 1] = {0};
        ioctl(f, EVIOCGBIT(EV_ABS, sizeof abs), abs);
        ioctl(f, EVIOCGBIT(EV_KEY, sizeof key), key);
        ioctl(f, EVIOCGPROP(sizeof prop), prop);
        if (BIT(abs, ABS_MT_POSITION_X) && BIT(abs, ABS_MT_POSITION_Y) && BIT(key, BTN_TOOL_TRIPLETAP) &&
            BIT(prop, INPUT_PROP_POINTER)) {
            char name[128] = "?";
            ioctl(f, EVIOCGNAME(sizeof name), name);
            fprintf(stderr, "gestured: using %s (%s)\n", p, name);
            unit_x = per_mm(f, ABS_MT_POSITION_X);
            unit_y = per_mm(f, ABS_MT_POSITION_Y);
            found = f;
        } else {
            close(f);
        }
    }
    closedir(d);
    return found;
}

static int tool_count(int code) {
    switch (code) {
        case BTN_TOOL_FINGER: return 1;
        case BTN_TOOL_DOUBLETAP: return 2;
        case BTN_TOOL_TRIPLETAP: return 3;
        case BTN_TOOL_QUADTAP: return 4;
        case BTN_TOOL_QUINTTAP: return 5;
    }
    return 0;
}

int main(int argc, char **argv) {
    signal(SIGPIPE, SIG_IGN);
    prctl(PR_SET_PDEATHSIG, SIGTERM);  // never outlive the supervisor loop that started us
    if (argc > 1 && strcmp(argv[1], "--probe")) snprintf(sock_path, sizeof sock_path, "%s", argv[1]);
    else snprintf(sock_path, sizeof sock_path, "%s/jellyface-gestures.sock", getenv("XDG_RUNTIME_DIR") ?: "/tmp");

    int denied = 0;
    fd = open_touchpad(&denied);
    if (argc > 1 && !strcmp(argv[1], "--probe")) return fd < 0 ? 3 : 0;  // for `jellyface doctor`
    if (fd < 0) {
        fprintf(stderr, denied ? "gestured: no permission to read the touchpad (install config/udev/70-jellyface-touchpad.rules, see README)\n"
                               : "gestured: no touchpad found\n");
        return 3;
    }

    // Slot state as the kernel reports it, and the current gesture
    int slot = 0, tid[NSLOTS], x[NSLOTS], y[NSLOTS];
    for (int i = 0; i < NSLOTS; i++) tid[i] = -1, x[i] = y[i] = 0;
    int tool = 0;              // finger count from BTN_TOOL_* (also covers more fingers than the pad has slots)
    int fingers = 0;           // fingers of the gesture in progress (0 = none)
    int fired = 0, blocked = 0;
    unsigned prev_set = 0;
    double cx0 = 0, cy0 = 0, dx = 0, dy = 0;
    const double trigger_mm = 9;   // travel needed before a swipe counts (shorter = snappier, longer = fewer mistakes)
    double t_start = 0;

    for (;;) {
        struct input_event ev[64];
        ssize_t r = read(fd, ev, sizeof ev);
        if (r < 0) {
            if (errno == EAGAIN || errno == EINTR) {
                struct pollfd p = { fd, POLLIN, 0 };
                poll(&p, 1, -1);
                continue;
            }
            return 1;  // device gone (ENODEV): exit, the supervisor starts us again
        }
        for (size_t i = 0; i < (size_t)r / sizeof *ev; i++) {
            struct input_event *e = &ev[i];
            if (e->type == EV_ABS) {
                if (e->code == ABS_MT_SLOT) slot = e->value;
                else if (slot >= 0 && slot < NSLOTS) {
                    if (e->code == ABS_MT_TRACKING_ID) tid[slot] = e->value;
                    else if (e->code == ABS_MT_POSITION_X) x[slot] = e->value;
                    else if (e->code == ABS_MT_POSITION_Y) y[slot] = e->value;
                }
            } else if (e->type == EV_KEY && tool_count(e->code)) {
                // the kernel releases the old BTN_TOOL_* and presses the new one in the same frame (order varies);
                // a release with no press after it means all fingers are up
                if (e->value) tool = tool_count(e->code);
                else if (tool == tool_count(e->code)) tool = 0;
            } else if (e->type == EV_SYN && e->code == SYN_DROPPED) {
                if (fingers) send_line("cancel %d\n", fingers);
                fingers = 0, blocked = 1;  // lost events: drop this gesture
            } else if (e->type == EV_SYN && e->code == SYN_REPORT) {
                unsigned set = 0;
                int n = 0;
                double cx = 0, cy = 0;
                for (int s = 0; s < NSLOTS; s++)
                    if (tid[s] >= 0) { set |= 1u << s; n++; cx += x[s]; cy += y[s]; }
                if (n) cx /= n, cy /= n;

                if (tool == 0) {             // all fingers up: next touch starts fresh
                    if (fingers) send_line("end %d %.1f %.1f\n", fingers, dx / unit_x, dy / unit_y);
                    fingers = 0, fired = 0, blocked = 0;
                } else if (blocked) {
                    // a gesture was cancelled or already ended by changing finger count: wait for a full lift
                } else if (fingers == 0 && tool >= 3) {
                    fingers = tool, fired = 0, dx = dy = 0, cx0 = cx, cy0 = cy, prev_set = set;
                    t_start = e->input_event_sec + e->input_event_usec / 1e6;
                    ensure_conn();
                    send_line("begin %d\n", fingers);
                } else if (fingers && tool != fingers) {
                    // finger count changed mid-swipe (e.g. 3 -> 4): not this gesture, nor a new one until lifted
                    send_line("cancel %d\n", fingers);
                    fingers = 0, blocked = 1;
                } else if (fingers && n) {
                    // follow the centroid; when a finger's slot changes the centroid jumps, so restart from there
                    if (set == prev_set) { dx += cx - cx0; dy += cy - cy0; }
                    cx0 = cx, cy0 = cy, prev_set = set;
                    double mx = dx / unit_x, my = dy / unit_y;
                    send_line("update %d %.1f %.1f\n", fingers, mx, my);
                    if (!fired && hypot(mx, my) >= trigger_mm) {
                        const char *dir = fabs(my) >= fabs(mx) * 1.5 ? (my < 0 ? "up" : "down")
                                        : fabs(mx) >= fabs(my) * 1.5 ? (mx < 0 ? "left" : "right") : NULL;
                        if (dir) {
                            send_line("swipe %d %s\n", fingers, dir);
                            struct timespec rt;
                            clock_gettime(CLOCK_REALTIME, &rt);  // evdev timestamps are CLOCK_REALTIME by default
                            fprintf(stderr, "gestured: swipe %d %s (%.0f ms after %d fingers touched)\n", fingers, dir,
                                    (rt.tv_sec + rt.tv_nsec / 1e9 - t_start) * 1000, fingers);
                        }
                        fired = 1;  // diagonal = no gesture, but still only one decision per swipe
                    }
                }
            }
        }
    }
}
