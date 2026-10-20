// Prints COSMIC's windows (ext-foreign-toplevel-list + cosmic-toplevel-info) as JSON lines whenever anything changes:
//   {"active":2,"fullscreen":false,"windows":[{"id":1,"app_id":"firefox","title":"...","activated":false,
//     "fullscreen":false,"maximized":false,"minimized":false,"workspace_active":true,"x":0,"y":0,"w":800,"h":600}, ...]}
// x/y/w/h: the window's rectangle on its output, in logical pixels (0x0 until COSMIC has sent it).
// "active" is the id of the focused window on the workspace you are looking at (0 = none); "fullscreen" is true when a
// window on that workspace is fullscreen. Windows on other workspaces never count.
// Read-only except for two commands on stdin: "activate <id>" focuses a window, "close <id>" asks it to close. Exits when its parent goes away or the compositor connection breaks.
#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <sys/prctl.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include "cosmic-toplevel-info-unstable-v1-client.h"
#include "cosmic-toplevel-management-unstable-v1-client.h"
#include "ext-foreign-toplevel-list-v1-client.h"
#include "ext-workspace-v1-client.h"

#define MAXWIN 256
struct win {
    int id;
    struct ext_foreign_toplevel_handle_v1 *ext;
    struct zcosmic_toplevel_handle_v1 *cosmic;
    char title[512], app_id[256];
    uint32_t state;  // bit n set = state n active (0 maximized, 1 minimized, 2 activated, 3 fullscreen)
    struct ext_workspace_handle_v1 *wsh[4];  // the workspaces this window is on (usually one)
    int nws;
    int x, y, w, h;  // geometry on its output (cosmic-toplevel-info v2)
    int ready;       // COSMIC has sent this window's state at least once
};

// workspaces and whether each is the one currently shown
struct wsinfo { struct ext_workspace_handle_v1 *h; uint32_t state; };
static struct wsinfo wss[64];
static int nwss;
static struct ext_workspace_manager_v1 *wsmgr;

static int ws_active(struct ext_workspace_handle_v1 *h) {
    for (int i = 0; i < nwss; i++) if (wss[i].h == h) return wss[i].state & 1;
    return 0;
}

// A window counts for the current view when it is on the shown workspace (or its workspace is unknown / it is on all)
static int on_current_ws(const struct win *w) {
    if (w->nws == 0) return 1;
    for (int i = 0; i < w->nws; i++) if (ws_active(w->wsh[i])) return 1;
    return 0;
}
static struct win *wins[MAXWIN];
// dirty: a batch of changes is complete (the protocols' "done" events), so the state is consistent and may be printed.
// Property events alone never print: a line written between "workspace A off" and "workspace B on" told the shell
// for a moment that nothing was fullscreen, and the bar, dock and island flickered on every switch.
// urgent: the batch changed focus, fullscreen, minimised or which windows are on the shown workspace; it is printed at
// once instead of waiting out the EMIT_MS throttle (meant for geometry and titles), so the shell reacts in the same frame.
static int nwins, next_id = 1, dirty, urgent;
// when a property first changed without its "done" yet (0 = nothing pending): printed anyway after STALE_MS, so a
// compositor that skips a "done" can never leave the shell with an old state
static long long changed_at;
static long long now_ms(void);
static void touch(void) { if (!changed_at) changed_at = now_ms(); }
static struct ext_foreign_toplevel_list_v1 *list;
static struct zcosmic_toplevel_info_v1 *info;
static struct zcosmic_toplevel_manager_v1 *mgmt;
static struct wl_seat *seat;
static struct wl_display *dpy;

// Output is built in memory and only written when it differs from the last line: COSMIC sends "done" for many
// events that change nothing we report (measured: 32 of 35 lines in 15 s were repeats), and every line costs the
// shell a JSON parse and a rebuild of everything bound to the window list.
static char *out_buf, *last_buf;
static size_t out_len, last_len;
static FILE *out;

static void json_str(const char *s) {
    fputc('"', out);
    for (; *s; s++) {
        unsigned char c = (unsigned char)*s;
        if (c == '"' || c == '\\') { fputc('\\', out); fputc(c, out); }
        else if (c < 0x20) fprintf(out, "\\u%04x", c);
        else fputc(c, out);
    }
    fputc('"', out);
}

static void emit(void) {
    int active = 0, fullscreen = 0;
    for (int i = 0; i < nwins; i++) {
        struct win *w = wins[i];
        if (!on_current_ws(w)) continue;  // windows on other workspaces never count (a fullscreen video elsewhere must not hide the shell here)
        if (w->state & (1u << 2)) active = w->id;
        if (((w->state >> 3) & 1) && !((w->state >> 1) & 1)) fullscreen = 1;
    }
    out = open_memstream(&out_buf, &out_len);
    if (!out) return;
    fprintf(out, "{\"active\":%d,\"fullscreen\":%s,\"windows\":[", active, fullscreen ? "true" : "false");
    for (int i = 0; i < nwins; i++) {
        struct win *w = wins[i];
        fprintf(out, "%s{\"id\":%d,\"app_id\":", i ? "," : "", w->id);
        json_str(w->app_id);
        fputs(",\"title\":", out);
        json_str(w->title);
        fprintf(out, ",\"activated\":%s,\"fullscreen\":%s,\"maximized\":%s,\"minimized\":%s,\"workspace_active\":%s",
               (w->state >> 2) & 1 ? "true" : "false", (w->state >> 3) & 1 ? "true" : "false",
               (w->state >> 0) & 1 ? "true" : "false", (w->state >> 1) & 1 ? "true" : "false", on_current_ws(w) ? "true" : "false");
        fprintf(out, ",\"x\":%d,\"y\":%d,\"w\":%d,\"h\":%d}", w->x, w->y, w->w, w->h);
    }
    fputs("]}\n", out);
    fclose(out);
    if (last_buf && out_len == last_len && !memcmp(out_buf, last_buf, out_len)) { free(out_buf); return; }
    fwrite(out_buf, 1, out_len, stdout);
    fflush(stdout);
    free(last_buf);
    last_buf = out_buf;
    last_len = out_len;
}

static long long now_ms(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1000LL + t.tv_nsec / 1000000;
}

static void win_remove(struct win *w) {
    for (int i = 0; i < nwins; i++)
        if (wins[i] == w) { memmove(&wins[i], &wins[i + 1], (nwins - i - 1) * sizeof *wins); nwins--; break; }
    if (w->cosmic) zcosmic_toplevel_handle_v1_destroy(w->cosmic);
    if (w->ext) ext_foreign_toplevel_handle_v1_destroy(w->ext);
    free(w);
    dirty = urgent = 1;
}

// --- ext_foreign_toplevel_handle_v1 -------------------------------------------------------------------------------
static void e_closed(void *d, struct ext_foreign_toplevel_handle_v1 *h) { win_remove(d); }
static void e_done(void *d, struct ext_foreign_toplevel_handle_v1 *h) { dirty = 1; }
// copy, cutting an over-long string at a character boundary (never in the middle of a UTF-8 sequence)
static void copy_utf8(char *dst, size_t size, const char *src) {
    size_t n = strlen(src);
    if (n >= size) {
        n = size - 1;
        while (n > 0 && ((unsigned char)src[n] & 0xC0) == 0x80) n--;
    }
    memcpy(dst, src, n);
    dst[n] = 0;
}
static void e_title(void *d, struct ext_foreign_toplevel_handle_v1 *h, const char *t) { touch(); copy_utf8(((struct win *)d)->title, sizeof(((struct win *)d)->title), t); }
static void e_app_id(void *d, struct ext_foreign_toplevel_handle_v1 *h, const char *a) { touch(); copy_utf8(((struct win *)d)->app_id, sizeof(((struct win *)d)->app_id), a); }
static void e_identifier(void *d, struct ext_foreign_toplevel_handle_v1 *h, const char *i) {}
static const struct ext_foreign_toplevel_handle_v1_listener ext_listener = {
    .closed = e_closed, .done = e_done, .title = e_title, .app_id = e_app_id, .identifier = e_identifier,
};

// --- zcosmic_toplevel_handle_v1 (state only; title/app_id come from the ext handle) --------------------------------
static void c_closed(void *d, struct zcosmic_toplevel_handle_v1 *h) {}
static void c_done(void *d, struct zcosmic_toplevel_handle_v1 *h) { ((struct win *)d)->ready = 1; dirty = 1; }
static void c_title(void *d, struct zcosmic_toplevel_handle_v1 *h, const char *t) {}
static void c_app_id(void *d, struct zcosmic_toplevel_handle_v1 *h, const char *a) {}
static void c_output(void *d, struct zcosmic_toplevel_handle_v1 *h, struct wl_output *o) {}
static void c_ws(void *d, struct zcosmic_toplevel_handle_v1 *h, struct zcosmic_workspace_handle_v1 *w) {}
static void c_ext_ws_enter(void *d, struct zcosmic_toplevel_handle_v1 *h, struct ext_workspace_handle_v1 *ws) {
    struct win *w = d;
    for (int i = 0; i < w->nws; i++) if (w->wsh[i] == ws) return;
    if (w->nws < 4) { w->wsh[w->nws++] = ws; urgent = 1; touch(); }
}
static void c_ext_ws_leave(void *d, struct zcosmic_toplevel_handle_v1 *h, struct ext_workspace_handle_v1 *ws) {
    struct win *w = d;
    for (int i = 0; i < w->nws; i++)
        if (w->wsh[i] == ws) { w->wsh[i] = w->wsh[--w->nws]; urgent = 1; touch(); return; }
}
static void c_geometry(void *d, struct zcosmic_toplevel_handle_v1 *h, struct wl_output *o, int32_t x, int32_t y, int32_t w, int32_t hh) {
    struct win *wn = d;
    if (wn->x != x || wn->y != y || wn->w != w || wn->h != hh) { wn->x = x; wn->y = y; wn->w = w; wn->h = hh; touch(); }
}
static void c_state(void *d, struct zcosmic_toplevel_handle_v1 *h, struct wl_array *arr) {
    struct win *w = d;
    uint32_t mask = 0, *s;
    wl_array_for_each(s, arr) if (*s < 32) mask |= 1u << *s;
    if (mask != w->state) { w->state = mask; urgent = 1; touch(); }
}
static const struct zcosmic_toplevel_handle_v1_listener cosmic_listener = {
    .closed = c_closed, .done = c_done, .title = c_title, .app_id = c_app_id,
    .output_enter = c_output, .output_leave = c_output, .workspace_enter = c_ws, .workspace_leave = c_ws,
    .state = c_state, .geometry = c_geometry, .ext_workspace_enter = c_ext_ws_enter, .ext_workspace_leave = c_ext_ws_leave,
};

// --- list ------------------------------------------------------------------------------------------------------
static void l_toplevel(void *d, struct ext_foreign_toplevel_list_v1 *l, struct ext_foreign_toplevel_handle_v1 *h) {
    if (nwins >= MAXWIN) { ext_foreign_toplevel_handle_v1_destroy(h); return; }
    struct win *w = calloc(1, sizeof *w);
    if (!w) { ext_foreign_toplevel_handle_v1_destroy(h); return; }
    w->id = next_id++;
    w->ext = h;
    urgent = 1;
    touch();
    wins[nwins++] = w;
    ext_foreign_toplevel_handle_v1_add_listener(h, &ext_listener, w);
    if (info) {
        w->cosmic = zcosmic_toplevel_info_v1_get_cosmic_toplevel(info, h);
        zcosmic_toplevel_handle_v1_add_listener(w->cosmic, &cosmic_listener, w);
    }
}
static void l_finished(void *d, struct ext_foreign_toplevel_list_v1 *l) { exit(0); }
static const struct ext_foreign_toplevel_list_v1_listener list_listener = { .toplevel = l_toplevel, .finished = l_finished };

static void i_toplevel(void *d, struct zcosmic_toplevel_info_v1 *i, struct zcosmic_toplevel_handle_v1 *h) { zcosmic_toplevel_handle_v1_destroy(h); }
static void i_finished(void *d, struct zcosmic_toplevel_info_v1 *i) {}
static void i_done(void *d, struct zcosmic_toplevel_info_v1 *i) { dirty = 1; }
static const struct zcosmic_toplevel_info_v1_listener info_listener = { .toplevel = i_toplevel, .finished = i_finished, .done = i_done };

static void wh_id(void *d, struct ext_workspace_handle_v1 *h, const char *id) {}
static void wh_name(void *d, struct ext_workspace_handle_v1 *h, const char *n) {}
static void wh_coord(void *d, struct ext_workspace_handle_v1 *h, struct wl_array *c) {}
static void wh_caps(void *d, struct ext_workspace_handle_v1 *h, uint32_t c) {}
static void wh_state(void *d, struct ext_workspace_handle_v1 *h, uint32_t st) {
    for (int i = 0; i < nwss; i++) if (wss[i].h == h) { if (wss[i].state != st) { wss[i].state = st; urgent = 1; touch(); } return; }
}
static void wh_removed(void *d, struct ext_workspace_handle_v1 *h) {
    // windows must not keep a pointer to a destroyed handle (a new handle could reuse the address)
    for (int i = 0; i < nwins; i++)
        for (int j = 0; j < wins[i]->nws; j++)
            if (wins[i]->wsh[j] == h) { wins[i]->wsh[j] = wins[i]->wsh[--wins[i]->nws]; j--; }
    for (int i = 0; i < nwss; i++)
        if (wss[i].h == h) { ext_workspace_handle_v1_destroy(h); memmove(&wss[i], &wss[i + 1], (nwss - i - 1) * sizeof *wss); nwss--; urgent = 1; touch(); return; }
}
static const struct ext_workspace_handle_v1_listener wh_listener = { wh_id, wh_name, wh_coord, wh_state, wh_caps, wh_removed };
static void wg_caps(void *d, struct ext_workspace_group_handle_v1 *g, uint32_t c) {}
static void wg_oe(void *d, struct ext_workspace_group_handle_v1 *g, struct wl_output *o) {}
static void wg_we(void *d, struct ext_workspace_group_handle_v1 *g, struct ext_workspace_handle_v1 *w) {}
static void wg_rm(void *d, struct ext_workspace_group_handle_v1 *g) {}
static const struct ext_workspace_group_handle_v1_listener wg_listener = { wg_caps, wg_oe, wg_oe, wg_we, wg_we, wg_rm };
static void wm_group(void *d, struct ext_workspace_manager_v1 *m, struct ext_workspace_group_handle_v1 *g) { ext_workspace_group_handle_v1_add_listener(g, &wg_listener, NULL); }
static void wm_ws(void *d, struct ext_workspace_manager_v1 *m, struct ext_workspace_handle_v1 *h) {
    if (nwss >= 64) return;
    wss[nwss].h = h; wss[nwss].state = 0; nwss++;
    ext_workspace_handle_v1_add_listener(h, &wh_listener, NULL);
}
static void wm_done(void *d, struct ext_workspace_manager_v1 *m) { dirty = 1; }
static void wm_fin(void *d, struct ext_workspace_manager_v1 *m) {}
static const struct ext_workspace_manager_v1_listener wm_listener = { wm_group, wm_ws, wm_done, wm_fin };

static void mg_caps(void *d, struct zcosmic_toplevel_manager_v1 *m, struct wl_array *c) {}
static const struct zcosmic_toplevel_manager_v1_listener mg_listener = { .capabilities = mg_caps };

static void reg(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t ver) {
    if (!strcmp(iface, wl_seat_interface.name) && !seat) {
        seat = wl_registry_bind(r, name, &wl_seat_interface, 1);
    } else if (!strcmp(iface, wl_output_interface.name)) {
        // never used directly, but COSMIC only sends a window's geometry for outputs this client has bound
        wl_registry_bind(r, name, &wl_output_interface, 1);
    } else if (!strcmp(iface, zcosmic_toplevel_manager_v1_interface.name)) {
        mgmt = wl_registry_bind(r, name, &zcosmic_toplevel_manager_v1_interface, ver < 2 ? ver : 2);
        zcosmic_toplevel_manager_v1_add_listener(mgmt, &mg_listener, NULL);
    } else if (!strcmp(iface, ext_foreign_toplevel_list_v1_interface.name)) {
        list = wl_registry_bind(r, name, &ext_foreign_toplevel_list_v1_interface, 1);
    } else if (!strcmp(iface, ext_workspace_manager_v1_interface.name)) {
        wsmgr = wl_registry_bind(r, name, &ext_workspace_manager_v1_interface, 1);
        ext_workspace_manager_v1_add_listener(wsmgr, &wm_listener, NULL);
    } else if (!strcmp(iface, zcosmic_toplevel_info_v1_interface.name)) {
        if (ver < 2) return;  // get_cosmic_toplevel needs version 2
        uint32_t v = ver < 3 ? ver : 3;
        info = wl_registry_bind(r, name, &zcosmic_toplevel_info_v1_interface, v);
        zcosmic_toplevel_info_v1_add_listener(info, &info_listener, NULL);
    }
}
static void reg_rm(void *d, struct wl_registry *r, uint32_t name) {}
static const struct wl_registry_listener reg_listener = { .global = reg, .global_remove = reg_rm };

// Commands on stdin: "activate <id>" focuses that window (switching to its workspace if needed); "close <id>" asks
// it to close (the app decides, exactly like its own close button: unsaved work prompts as usual).
static void handle_command(char *line) {
    int id, close = 0;
    if (sscanf(line, "activate %d", &id) != 1) {
        if (sscanf(line, "close %d", &id) != 1) return;
        close = 1;
    }
    if (!mgmt || (!close && !seat)) return;
    for (int i = 0; i < nwins; i++)
        if (wins[i]->id == id && wins[i]->cosmic) {
            if (close) zcosmic_toplevel_manager_v1_close(mgmt, wins[i]->cosmic);
            else zcosmic_toplevel_manager_v1_activate(mgmt, wins[i]->cosmic, seat);
            wl_display_flush(dpy);
            return;
        }
}

int main(void) {
    dpy = wl_display_connect(NULL);
    if (!dpy) { fprintf(stderr, "cannot connect to wayland\n"); return 1; }
    wl_registry_add_listener(wl_display_get_registry(dpy), &reg_listener, NULL);
    wl_display_roundtrip(dpy);
    if (!list) { fprintf(stderr, "no ext_foreign_toplevel_list_v1\n"); return 2; }
    if (!info) { fprintf(stderr, "no zcosmic_toplevel_info_v1 (window state will be unavailable)\n"); }
    ext_foreign_toplevel_list_v1_add_listener(list, &list_listener, NULL);
    wl_display_roundtrip(dpy);  // the toplevels (their cosmic handles are requested as they arrive)
    wl_display_roundtrip(dpy);
    // COSMIC sends those handles' state a little later, not in reply to a roundtrip. The first line used to go out
    // before it, with every window unfocused, not fullscreen and on the shown workspace (the shell showed the bar
    // over a fullscreen video for a moment): wait until each window has reported, at most half a second.
    for (long long until = now_ms() + 500; info && now_ms() < until;) {
        int all = 1;
        for (int i = 0; i < nwins; i++) all &= wins[i]->ready;
        if (all) break;
        if (wl_display_flush(dpy) < 0 && errno != EAGAIN) return 1;
        struct pollfd p = { wl_display_get_fd(dpy), POLLIN, 0 };
        if (poll(&p, 1, (int)(until - now_ms())) > 0 && wl_display_dispatch(dpy) < 0) return 1;
    }
    emit();
    dirty = urgent = 0;
    changed_at = 0;
    int stdin_ok = 1;
    // a window being dragged or resized sends geometry every frame: write at most one line per EMIT_MS (the last
    // state always goes out, via the poll timeout), so the shell is not re-parsing the window list 60 times a second
    enum { EMIT_MS = 80, STALE_MS = 250 };
    long long last_emit = 0;
    const pid_t parent = getppid();  // exit when whoever started us goes away (no orphans), without periodic wake-ups
    prctl(PR_SET_PDEATHSIG, SIGTERM);
    if (getppid() != parent) return 0;
    for (;;) {
        while (wl_display_prepare_read(dpy) != 0) wl_display_dispatch_pending(dpy);
        if (wl_display_flush(dpy) < 0 && errno != EAGAIN) return 1;
        struct pollfd pp[2] = { { wl_display_get_fd(dpy), POLLIN, 0 }, { stdin_ok ? 0 : -1, POLLIN, 0 } };
        if (!dirty && changed_at && now_ms() - changed_at >= STALE_MS) dirty = 1;
        int timeout = dirty ? (urgent ? 0 : (int)(last_emit + EMIT_MS - now_ms()))
                    : changed_at ? (int)(changed_at + STALE_MS - now_ms()) : -1;
        poll(pp, 2, timeout < 0 && (dirty || changed_at) ? 0 : timeout);
        struct pollfd p = pp[0];
        if (p.revents & POLLIN) { if (wl_display_read_events(dpy) < 0) return 1; } else wl_display_cancel_read(dpy);
        if (wl_display_dispatch_pending(dpy) < 0 || wl_display_get_error(dpy)) return 1;
        if (p.revents & (POLLHUP | POLLERR)) return 1;
        if (pp[1].revents & (POLLIN | POLLHUP | POLLERR)) {
            // read(), not stdio: a second command buffered by fgets would wait for the next compositor event
            static char cmd[256];
            static size_t have;
            ssize_t r = read(0, cmd + have, sizeof cmd - 1 - have);
            if (r <= 0) stdin_ok = 0;
            else {
                have += r;
                char *nl;
                while ((nl = memchr(cmd, '\n', have))) {
                    *nl = 0;
                    handle_command(cmd);
                    have -= nl + 1 - cmd;
                    memmove(cmd, nl + 1, have);
                }
                if (have == sizeof cmd - 1) have = 0;  // overlong garbage line: drop it
            }
        }
        if (dirty && (urgent || now_ms() - last_emit >= EMIT_MS)) { dirty = urgent = 0; changed_at = 0; emit(); last_emit = now_ms(); }
    }
}
