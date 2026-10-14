//! Turns a JellyFace colour scheme (scheme.json) into COSMIC's own dark theme, so COSMIC apps (Files, Terminal,
//! Settings, the panel...) follow the same palette as the JellyFace shell.
//!
//! It only *writes theme files* (via COSMIC's own theme library) into the config directory it is pointed at
//! (XDG_CONFIG_HOME); the wrapper script decides what actually reaches ~/.config/cosmic.
//!
//!   jellyface-cosmic-theme <scheme.json>
use cosmic_config::CosmicConfigEntry;
use cosmic_theme::palette::{Srgb, Srgba};
use cosmic_theme::{Theme, ThemeBuilder};
use std::{env, fs, process::exit};

fn hex(s: &serde_json::Value, key: &str) -> Srgb {
    let h = s["colours"][key].as_str().unwrap_or_else(|| {
        eprintln!("scheme.json has no colour '{key}'");
        exit(2)
    });
    let v = u32::from_str_radix(h.trim_start_matches('#'), 16).unwrap_or_else(|_| {
        eprintln!("bad colour '{h}' for '{key}'");
        exit(2)
    });
    Srgb::new(((v >> 16) & 0xff) as f32 / 255.0, ((v >> 8) & 0xff) as f32 / 255.0, (v & 0xff) as f32 / 255.0)
}

fn opaque(c: Srgb) -> Srgba {
    Srgba::new(c.red, c.green, c.blue, 1.0)
}

fn main() {
    let path = env::args().nth(1).unwrap_or_else(|| {
        eprintln!("usage: jellyface-cosmic-theme <scheme.json>");
        exit(1)
    });
    let scheme: serde_json::Value = serde_json::from_str(&fs::read_to_string(&path).unwrap_or_else(|e| {
        eprintln!("cannot read {path}: {e}");
        exit(1)
    }))
    .unwrap_or_else(|e| {
        eprintln!("{path} is not valid JSON: {e}");
        exit(1)
    });

    let mut builder = ThemeBuilder::dark();
    builder.bg_color = Some(opaque(hex(&scheme, "background")));
    builder.primary_container_bg = Some(opaque(hex(&scheme, "surfaceContainer")));
    builder.secondary_container_bg = Some(opaque(hex(&scheme, "surfaceContainerHigh")));
    builder.accent = Some(hex(&scheme, "secondary"));
    builder.neutral_tint = Some(hex(&scheme, "surfaceContainerHigh"));
    builder.text_tint = Some(hex(&scheme, "onSurface"));

    let theme = builder.clone().build();
    let b_cfg = ThemeBuilder::dark_config().unwrap_or_else(|e| {
        eprintln!("builder config: {e}");
        exit(1)
    });
    let t_cfg = Theme::dark_config().unwrap_or_else(|e| {
        eprintln!("theme config: {e}");
        exit(1)
    });
    if let Err(e) = builder.write_entry(&b_cfg) {
        eprintln!("writing builder: {e}");
        exit(1)
    }
    if let Err(e) = theme.write_entry(&t_cfg) {
        eprintln!("writing theme: {e}");
        exit(1)
    }
    println!("wrote COSMIC dark theme from {path}");
}
