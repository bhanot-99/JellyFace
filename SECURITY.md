# Security notes

## Lock screen

- JellyFace locks the session with the standard Wayland **ext-session-lock** protocol. While locked, COSMIC shows
  nothing but the lock surfaces and sends no input to other apps.
- **Password check.** The shell runs in a container whose user account has no password, so the container's own PAM
  would accept any input. The lock screen's PAM stack (`config/pam-passwd.tmpl`) therefore calls
  `scripts/pam-host-check.sh`, which asks the **host's** `unix_chkpwd` to verify the password. Any error rejects the
  password (fails closed). `jellyface doctor` checks that a wrong password is rejected and that the PAM stack contains
  no `nullok`.
- **If the shell dies while locked**, the compositor keeps the session locked (required by the protocol). The
  supervisor sees the runtime flag `$XDG_RUNTIME_DIR/jellyface-locked` and asks logind to lock the session, which
  brings up COSMIC's own lock screen (COSMIC accepts a new locker once the previous one is gone). You never get an
  unlocked desktop, and never a locked one you can't unlock.

## Clipboard history

Stored in `~/.local/state/jellyface/clipboard/` with permissions `0700`/`0600`. Content that a password manager marks
with `x-kde-passwordManagerHint` is never stored. Clear it from the clipboard popup or delete the folder.

## Changes outside the project

Every file JellyFace writes outside `~/JellyFace` is recorded in `~/.local/state/jellyface/system-manifest.tsv` with
a copy of the original in `backups/system/`; `jellyface revert-system` restores them. No `sudo` is used on the host
except by the optional login screen (`jellyface greeter`), which installs a sudoers rule allowing one fixed,
argument-less helper.

## Reporting a problem

Open an issue at https://github.com/bhanot-99/JellyFace with steps to reproduce. For anything that could let
someone past the lock screen, please mark the issue as security-related and leave out exploit details.
