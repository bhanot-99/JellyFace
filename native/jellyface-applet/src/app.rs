//! JellyFace as a native COSMIC panel applet: one logo button, one popup menu.
//! It does not re-implement anything; it calls the `jellyface` command line, so the shell, the applet and the
//! terminal always agree.
use cosmic::app::{Core, Task};
use cosmic::iced::window::Id;
use cosmic::iced::{Rectangle, Subscription};
use cosmic::iced_runtime::core::window;
use cosmic::surface::action::{app_popup, destroy_popup};
use cosmic::widget::{self, icon, list_column, settings, toggler};
use cosmic::Element;
use std::{path::PathBuf, process::Command, time::Duration};

const APP_ID: &str = "com.jellyface.Applet";
// the one-colour mark: COSMIC tints it like its other panel icons (face bright, hair dimmer, eyes cut out)
const LOGO: &[u8] = include_bytes!("../../../assets/jellyface-symbolic.svg");

/// Where JellyFace lives: $JELLYFACE_ROOT, or ~/JellyFace.
fn root() -> PathBuf {
    std::env::var_os("JELLYFACE_ROOT").map(PathBuf::from).unwrap_or_else(|| {
        PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join("JellyFace")
    })
}

/// Run a command in the background without waiting for it.
fn spawn(program: PathBuf, args: Vec<String>) {
    if let Ok(mut child) = Command::new(program).args(args).spawn() {
        std::thread::spawn(move || {
            let _ = child.wait();
        });
    }
}

fn jellyface(args: &[&str]) {
    spawn(root().join("bin/jellyface"), args.iter().map(|s| s.to_string()).collect());
}

#[derive(Clone, Debug, Default)]
struct ThemeInfo {
    name: String,
    family: String,
    auto: bool,
    system: bool,
}

fn read_theme() -> ThemeInfo {
    let state = std::env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/state"));
    let v: serde_json::Value = std::fs::read_to_string(state.join("jellyface/theme.json"))
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default();
    ThemeInfo {
        name: v["name"].as_str().unwrap_or("not applied yet").to_string(),
        family: v["family"].as_str().unwrap_or("").to_string(),
        auto: v["mode"].as_str().unwrap_or("auto") == "auto",
        system: v["system"].as_bool().unwrap_or(true),
    }
}

pub struct App {
    core: Core,
    popup: Option<Id>,
    theme: ThemeInfo,
}

#[derive(Clone, Debug)]
pub enum Message {
    Surface(cosmic::surface::Action),
    PopupClosed(Id),
    Tick,
    Jellyface(&'static [&'static str]),
    LockScreen,
    ToggleAuto(bool),
    ToggleSystem(bool),
}

impl cosmic::Application for App {
    type Executor = cosmic::SingleThreadExecutor;
    type Flags = ();
    type Message = Message;
    const APP_ID: &'static str = APP_ID;

    fn core(&self) -> &Core {
        &self.core
    }

    fn core_mut(&mut self) -> &mut Core {
        &mut self.core
    }

    fn init(core: Core, _flags: Self::Flags) -> (Self, Task<Message>) {
        (App { core, popup: None, theme: read_theme() }, Task::none())
    }

    fn on_close_requested(&self, id: window::Id) -> Option<Message> {
        Some(Message::PopupClosed(id))
    }

    fn subscription(&self) -> Subscription<Message> {
        // keep the "current theme" line fresh while the menu is open; with the menu closed the applet sleeps (it used to
        // wake up and redraw every 3 s all day for a line nobody could see)
        if self.popup.is_some() {
            cosmic::iced::time::every(Duration::from_secs(3)).map(|_| Message::Tick)
        } else {
            Subscription::none()
        }
    }

    fn update(&mut self, message: Message) -> Task<Message> {
        match message {
            Message::Surface(a) => {
                return cosmic::task::message(cosmic::Action::Cosmic(cosmic::app::Action::Surface(a)));
            }
            Message::PopupClosed(id) => {
                if self.popup == Some(id) {
                    self.popup = None;
                }
            }
            Message::Tick => self.theme = read_theme(),
            Message::Jellyface(args) => {
                jellyface(args);
                return self.close_popup();
            }
            Message::LockScreen => {
                // JellyFace's own lock screen, the same as Super+L (loginctl lock-session would also wake COSMIC's)
                jellyface(&["lock"]);
                return self.close_popup();
            }
            Message::ToggleAuto(on) => {
                self.theme.auto = on;
                jellyface(&["theme", "auto", if on { "on" } else { "off" }]);
            }
            Message::ToggleSystem(on) => {
                self.theme.system = on;
                jellyface(&["theme", "system", if on { "on" } else { "off" }]);
            }
        }
        Task::none()
    }

    fn view(&self) -> Element<'_, Message> {
        let have_popup = self.popup;
        let button = self
            .core
            .applet
            .icon_button_from_handle(icon::from_svg_bytes(LOGO).symbolic(true))
            .on_press_with_rectangle(move |offset, bounds| {
                if let Some(id) = have_popup {
                    Message::Surface(destroy_popup(id))
                } else {
                    Message::Surface(app_popup::<App>(
                        move |state: &mut App| {
                            let new_id = Id::unique();
                            state.popup = Some(new_id);
                            state.theme = read_theme();
                            let mut settings = state.core.applet.get_popup_settings(
                                state.core.main_window_id().unwrap(),
                                new_id,
                                None,
                                None,
                                None,
                            );
                            settings.positioner.anchor_rect = Rectangle {
                                x: (bounds.x - offset.x) as i32,
                                y: (bounds.y - offset.y) as i32,
                                width: bounds.width as i32,
                                height: bounds.height as i32,
                            };
                            settings
                        },
                        Some(Box::new(|state: &App| {
                            Element::from(state.core.applet.popup_container(state.menu())).map(cosmic::Action::App)
                        })),
                    ))
                }
            });

        Element::from(self.core.applet.applet_tooltip::<Message>(
            button,
            "JellyFace",
            self.popup.is_some(),
            Message::Surface,
            None,
        ))
    }

    fn view_window(&self, _id: Id) -> Element<'_, Message> {
        "".into()
    }

    fn style(&self) -> Option<cosmic::iced_core::theme::Style> {
        Some(cosmic::applet::style())
    }
}

impl App {
    fn close_popup(&mut self) -> Task<Message> {
        match self.popup.take() {
            Some(id) => cosmic::task::message(cosmic::Action::Cosmic(cosmic::app::Action::Surface(destroy_popup(id)))),
            None => Task::none(),
        }
    }

    fn menu(&self) -> Element<'_, Message> {
        let item = |label: &'static str, msg: Message| {
            cosmic::applet::menu_button(widget::text::body(label)).on_press(msg)
        };
        let theme = format!(
            "{}{}",
            self.theme.name,
            if self.theme.family.is_empty() { String::new() } else { format!(" ({})", self.theme.family) }
        );
        list_column()
            .padding(5)
            .spacing(0)
            .add(settings::item("Theme", widget::text::body(theme)))
            .add(settings::item("Follow the wallpaper", toggler(self.theme.auto).on_toggle(Message::ToggleAuto)))
            .add(settings::item("Theme COSMIC apps too", toggler(self.theme.system).on_toggle(Message::ToggleSystem)))
            .add(item("Open launcher", Message::Jellyface(&["ipc", "drawers", "toggle", "launcher"])))
            .add(item("Show dashboard", Message::Jellyface(&["ipc", "drawers", "toggle", "dashboard"])))
            .add(item("Show notifications", Message::Jellyface(&["ipc", "drawers", "toggle", "sidebar"])))
            .add(item("Lock screen", Message::LockScreen))
            .add(item("Restart JellyFace", Message::Jellyface(&["restart"])))
            .into()
    }
}
