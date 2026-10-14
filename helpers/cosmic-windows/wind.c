// Prints COSMIC's windows (ext-foreign-toplevel-list + cosmic-toplevel-info) as JSON lines whenever anything changes:
//   {"active":2,"fullscreen":false,"windows":[{"id":1,"app_id":"firefox","title":"...","activated":false,
//     "fullscreen":false,"maximized":false,"minimized":false,"workspace_active":true}, ...]}
// "active" is the id of the focused window on the workspace you are looking at (0 = none); "fullscreen" is true when a
// window on that workspace is fullscreen. Windows on other workspaces never count.
// Read-only: it never changes windows. Exits when its parent goes away or the compositor connection breaks.
#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <sys/prctl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include "cosmic-toplevel-info-unstable-v1-client.h"
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
static int nwins, next_id = 1, dirty;
static struct ext_foreign_toplevel_list_v1 *list;
static struct zcosmic_toplevel_info_v1 *info;
static struct wl_display *dpy;

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

static void emit(void) {
    int active = 0, fullscreen = 0;
    for (int i = 0; i < nwins; i++) {
        struct win *w = wins[i];
        if (!on_current_ws(w)) continue;  // windows on other workspaces never count (a fullscreen video elsewhere must not hide the shell here)
        if (w->state & (1u << 2)) active = w->id;
        if (((w->state >> 3) & 1) && !((w->state >> 1) & 1)) fullscreen = 1;
    }
    printf("{\"active\":%d,\"fullscreen\":%s,\"windows\":[", active, fullscreen ? "true" : "false");
    for (int i = 0; i < nwins; i++) {
        struct win *w = wins[i];
        printf("%s{\"id\":%d,\"app_id\":", i ? "," : "", w->id);
        json_str(w->app_id);
        printf(",\"title\":");
        json_str(w->title);
        printf(",\"activated\":%s,\"fullscreen\":%s,\"maximized\":%s,\"minimized\":%s,\"workspace_active\":%s}",
               (w->state >> 2) & 1 ? "true" : "false", (w->state >> 3) & 1 ? "true" : "false",
               (w->state >> 0) & 1 ? "true" : "false", (w->state >> 1) & 1 ? "true" : "false", on_current_ws(w) ? "true" : "false");
    }
    printf("]}\n");
    fflush(stdout);
}

static void win_remove(struct win *w) {
    for (int i = 0; i < nwins; i++)
        if (wins[i] == w) { memmove(&wins[i], &wins[i + 1], (nwins - i - 1) * sizeof *wins); nwins--; break; }
    if (w->cosmic) zcosmic_toplevel_handle_v1_destroy(w->cosmic);
    if (w->ext) ext_foreign_toplevel_handle_v1_destroy(w->ext);
    free(w);
    dirty = 1;
}

// --- ext_foreign_toplevel_handle_v1 -------------------------------------------------------------------------------
static void e_closed(void *d, struct ext_foreign_toplevel_handle_v1 *h) { win_remove(d); }
static void e_done(void *d, struct ext_foreign_toplevel_handle_v1 *h) { dirty = 1; }
static void e_title(void *d, struct ext_foreign_toplevel_handle_v1 *h, const char *t) { snprintf(((struct win *)d)->title, sizeof(((struct win *)d)->title), "%s", t); }
static void e_app_id(void *d, struct ext_foreign_toplevel_handle_v1 *h, const char *a) { snprintf(((struct win *)d)->app_id, sizeof(((struct win *)d)->app_id), "%s", a); }
static void e_identifier(void *d, struct ext_foreign_toplevel_handle_v1 *h, const char *i) {}
static const struct ext_foreign_toplevel_handle_v1_listener ext_listener = {
    .closed = e_closed, .done = e_done, .title = e_title, .app_id = e_app_id, .identifier = e_identifier,
};

// --- zcosmic_toplevel_handle_v1 (state only; title/app_id come from the ext handle) --------------------------------
static void c_closed(void *d, struct zcosmic_toplevel_handle_v1 *h) {}
static void c_done(void *d, struct zcosmic_toplevel_handle_v1 *h) { dirty = 1; }
static void c_title(void *d, struct zcosmic_toplevel_handle_v1 *h, const char *t) {}
static void c_app_id(void *d, struct zcosmic_toplevel_handle_v1 *h, const char *a) {}
static void c_output(void *d, struct zcosmic_toplevel_handle_v1 *h, struct wl_output *o) {}
static void c_ws(void *d, struct zcosmic_toplevel_handle_v1 *h, struct zcosmic_workspace_handle_v1 *w) {}
static void c_ext_ws_enter(void *d, struct zcosmic_toplevel_handle_v1 *h, struct ext_workspace_handle_v1 *ws) {
    struct win *w = d;
    for (int i = 0; i < w->nws; i++) if (w->wsh[i] == ws) return;
    if (w->nws < 4) { w->wsh[w->nws++] = ws; dirty = 1; }
}
static void c_ext_ws_leave(void *d, struct zcosmic_toplevel_handle_v1 *h, struct ext_workspace_handle_v1 *ws) {
    struct win *w = d;
    for (int i = 0; i < w->nws; i++)
        if (w->wsh[i] == ws) { w->wsh[i] = w->wsh[--w->nws]; dirty = 1; return; }
}
static void c_geometry(void *d, struct zcosmic_toplevel_handle_v1 *h, struct wl_output *o, int32_t x, int32_t y, int32_t w, int32_t hh) {}
static void c_state(void *d, struct zcosmic_toplevel_handle_v1 *h, struct wl_array *arr) {
    struct win *w = d;
    uint32_t mask = 0, *s;
    wl_array_for_each(s, arr) if (*s < 32) mask |= 1u << *s;
    if (mask != w->state) { w->state = mask; dirty = 1; }
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
    w->id = next_id++;
    w->ext = h;
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
    for (int i = 0; i < nwss; i++) if (wss[i].h == h) { if (wss[i].state != st) { wss[i].state = st; dirty = 1; } return; }
}
static void wh_removed(void *d, struct ext_workspace_handle_v1 *h) {
    for (int i = 0; i < nwss; i++)
        if (wss[i].h == h) { ext_workspace_handle_v1_destroy(h); memmove(&wss[i], &wss[i + 1], (nwss - i - 1) * sizeof *wss); nwss--; dirty = 1; return; }
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

static void reg(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t ver) {
    if (!strcmp(iface, ext_foreign_toplevel_list_v1_interface.name)) {
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

int main(void) {
    dpy = wl_display_connect(NULL);
    if (!dpy) { fprintf(stderr, "cannot connect to wayland\n"); return 1; }
    wl_registry_add_listener(wl_display_get_registry(dpy), &reg_listener, NULL);
    wl_display_roundtrip(dpy);
    if (!list) { fprintf(stderr, "no ext_foreign_toplevel_list_v1\n"); return 2; }
    if (!info) { fprintf(stderr, "no zcosmic_toplevel_info_v1 (window state will be unavailable)\n"); }
    ext_foreign_toplevel_list_v1_add_listener(list, &list_listener, NULL);
    wl_display_roundtrip(dpy);
    wl_display_roundtrip(dpy);
    emit();
    dirty = 0;
    const pid_t parent = getppid();  // exit when whoever started us goes away (no orphans), without periodic wake-ups
    prctl(PR_SET_PDEATHSIG, SIGTERM);
    if (getppid() != parent) return 0;
    for (;;) {
        while (wl_display_prepare_read(dpy) != 0) wl_display_dispatch_pending(dpy);
        if (wl_display_flush(dpy) < 0 && errno != EAGAIN) return 1;
        struct pollfd p = { wl_display_get_fd(dpy), POLLIN, 0 };
        poll(&p, 1, -1);
        if (p.revents & POLLIN) { if (wl_display_read_events(dpy) < 0) return 1; } else wl_display_cancel_read(dpy);
        if (wl_display_dispatch_pending(dpy) < 0 || wl_display_get_error(dpy)) return 1;
        if (p.revents & (POLLHUP | POLLERR)) return 1;
        if (dirty) { dirty = 0; emit(); }
    }
}
