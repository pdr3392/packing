# Backends

The executable detects these managers when their commands are available:

- `pacman`
- `yay`
- `flatpak`
- `snap`
- `apt` or read-only `dpkg`
- `dnf`, `zypper`, or read-only `rpm`
- `brew`
- `emerge`
- `xbps`
- `nix-env`

The `yay` backend lists explicit foreign/AUR packages with `yay -Qem` and falls
back to the equivalent `pacman -Qem` query if the helper produces no output.

Read-only backends can list and show package metadata but do not expose safe
generic update/reinstall actions in this script.
