// Prints COSMIC workspaces (ext-workspace-v1) as JSON lines; reads "activate <index>" from stdin.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <poll.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <sys/prctl.h>
#include <wayland-client.h>
#include "ext-workspace-v1-client.h"

#define MAXWS 64
struct ws { struct ext_workspace_handle_v1 *h; char name[64]; uint32_t state; };
static struct ws list[MAXWS]; static int n;
static struct ext_workspace_manager_v1 *mgr;
static struct wl_display *dpy;

static struct ws *find(struct ext_workspace_handle_v1 *h) { for (int i = 0; i < n; i++) if (list[i].h == h) return &list[i]; return NULL; }

static void h_id(void *d, struct ext_workspace_handle_v1 *h, const char *id) {}
static void h_name(void *d, struct ext_workspace_handle_v1 *h, const char *name) { struct ws *w = find(h); if (w) snprintf(w->name, sizeof w->name, "%s", name); }
static void h_coord(void *d, struct ext_workspace_handle_v1 *h, struct wl_array *c) {}
static void h_state(void *d, struct ext_workspace_handle_v1 *h, uint32_t s) { struct ws *w = find(h); if (w) w->state = s; }
static void h_caps(void *d, struct ext_workspace_handle_v1 *h, uint32_t c) {}
static void h_removed(void *d, struct ext_workspace_handle_v1 *h) {
    for (int i = 0; i < n; i++) if (list[i].h == h) { ext_workspace_handle_v1_destroy(h); memmove(&list[i], &list[i + 1], (n - i - 1) * sizeof *list); n--; return; }
}
static const struct ext_workspace_handle_v1_listener hl = { h_id, h_name, h_coord, h_state, h_caps, h_removed };

static void g_caps(void *d, struct ext_workspace_group_handle_v1 *g, uint32_t c) {}
static void g_oe(void *d, struct ext_workspace_group_handle_v1 *g, struct wl_output *o) {}
static void g_ol(void *d, struct ext_workspace_group_handle_v1 *g, struct wl_output *o) {}
static void g_we(void *d, struct ext_workspace_group_handle_v1 *g, struct ext_workspace_handle_v1 *w) {}
static void g_wl(void *d, struct ext_workspace_group_handle_v1 *g, struct ext_workspace_handle_v1 *w) {}
static void g_rm(void *d, struct ext_workspace_group_handle_v1 *g) {}
static const struct ext_workspace_group_handle_v1_listener gl = { g_caps, g_oe, g_ol, g_we, g_wl, g_rm };

static void m_group(void *d, struct ext_workspace_manager_v1 *m, struct ext_workspace_group_handle_v1 *g) { ext_workspace_group_handle_v1_add_listener(g, &gl, NULL); }
static void m_ws(void *d, struct ext_workspace_manager_v1 *m, struct ext_workspace_handle_v1 *h) {
    if (n >= MAXWS) return;
    memset(&list[n], 0, sizeof list[n]); list[n].h = h; n++;
    ext_workspace_handle_v1_add_listener(h, &hl, NULL);
}
static void json_str(const char *s) {
    putchar('"');
    for (; *s; s++) {
        unsigned char c = (unsigned char)*s;
        if (c == '"' || c == '\\') { putchar('\\'); putchar(c); }
        else if (c < 0x20) printf("\\u%04x", c);
        else putchar(c);
    }
    putchar('"');
}
static void m_done(void *d, struct ext_workspace_manager_v1 *m) {
    printf("{\"ws\":[");
    for (int i = 0; i < n; i++) {
        printf("%s{\"i\":%d,\"name\":", i ? "," : "", i);
        json_str(list[i].name);
        printf(",\"active\":%s,\"urgent\":%s,\"hidden\":%s}",
               list[i].state & 1 ? "true" : "false", list[i].state & 2 ? "true" : "false", list[i].state & 4 ? "true" : "false");
    }
    printf("]}\n"); fflush(stdout);
}
static void m_fin(void *d, struct ext_workspace_manager_v1 *m) { exit(0); }
static const struct ext_workspace_manager_v1_listener ml = { m_group, m_ws, m_done, m_fin };

static void reg(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t ver) {
    if (!strcmp(iface, ext_workspace_manager_v1_interface.name)) {
        mgr = wl_registry_bind(r, name, &ext_workspace_manager_v1_interface, 1);
        ext_workspace_manager_v1_add_listener(mgr, &ml, NULL);
    }
}
static void reg_rm(void *d, struct wl_registry *r, uint32_t name) {}
static const struct wl_registry_listener rl = { reg, reg_rm };

int main(void) {
    dpy = wl_display_connect(NULL);
    if (!dpy) { fprintf(stderr, "cannot connect to wayland\n"); return 1; }
    wl_registry_add_listener(wl_display_get_registry(dpy), &rl, NULL);
    wl_display_roundtrip(dpy);
    if (!mgr) { fprintf(stderr, "no ext_workspace_manager_v1\n"); return 2; }
    char buf[128]; int stdin_ok = 1;
    // exit when whoever started us goes away (no orphans): the kernel tells us, so there is no need to wake up
    // every couple of seconds just to check
    const pid_t parent = getppid();
    prctl(PR_SET_PDEATHSIG, SIGTERM);
    if (getppid() != parent) return 0;
    setvbuf(stdin, NULL, _IOLBF, 0);
    for (;;) {
        while (wl_display_prepare_read(dpy) != 0) wl_display_dispatch_pending(dpy);
        if (wl_display_flush(dpy) < 0 && errno != EAGAIN) return 1;   // compositor went away
        struct pollfd p[2] = { { wl_display_get_fd(dpy), POLLIN, 0 }, { stdin_ok ? 0 : -1, POLLIN, 0 } };
        poll(p, 2, -1);
        if (p[0].revents & POLLIN) { if (wl_display_read_events(dpy) < 0) return 1; } else wl_display_cancel_read(dpy);
        if (wl_display_dispatch_pending(dpy) < 0 || wl_display_get_error(dpy)) return 1;
        if (p[0].revents & (POLLHUP | POLLERR)) return 1;
        if (p[1].revents & POLLIN) {
            if (!fgets(buf, sizeof buf, stdin)) { stdin_ok = 0; continue; }
            int i;
            if (sscanf(buf, "activate %d", &i) == 1 && i >= 0 && i < n) {
                ext_workspace_handle_v1_activate(list[i].h);
                ext_workspace_manager_v1_commit(mgr);
                wl_display_flush(dpy);
            }
        } else if (p[1].revents & (POLLHUP | POLLERR)) stdin_ok = 0;
    }
}
