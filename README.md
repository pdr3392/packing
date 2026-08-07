# package-manager-cli

Linux package manager helper with an interactive `fzf` interface, CLI commands,
package-manager autodetection, package-list cache, and integrity checks where
the underlying manager supports them.

The interactive UI shows one package manager at a time. Use `Shift+Tab` to cycle
between detected managers such as `pacman`, `yay`, `flatpak`, `snap`, `apt`,
`dnf`, `rpm`, and others. Package actions use uppercase keys (`Shift+U`,
`Shift+R`, `Shift+D`, `Shift+V`, `Shift+F`) so lowercase package searches are
not intercepted by hotkeys. Details are opened with `Shift+I`.

## Usage

```bash
bin/package-manager
bin/package-manager managers
bin/package-manager list all
bin/package-manager --refresh list pacman
bin/package-manager verify pacman bash
bin/package-manager fix pacman bash
bin/package-manager cache status
bin/package-manager cache clear
```

## Cache

Package listings are cached in `cache/` by default when running from this
project directory. Override with:

```bash
PACKAGE_MANAGER_CACHE_DIR=/tmp/pkg-cache bin/package-manager list all
PACKAGE_MANAGER_CACHE_TTL=60 bin/package-manager list all
```

CLI flags:

- `--refresh`: rebuild package-list cache before reading it.
- `--no-cache`: query package managers directly.
- `--cache-ttl <seconds>`: change the cache TTL for this run.

## Integrity Checks

Supported checks depend on the backend:

- `pacman`/`yay`: `pacman -Qk`
- `apt`/`dpkg`: `debsums -s` when available, otherwise `dpkg --verify`
- `dnf`/`zypper`/`rpm`: `rpm -V`
- `flatpak`: `flatpak repair --dry-run` installation-wide
- `brew`: `brew linkage --test`

Fix actions usually reinstall the selected package. Flatpak uses
`flatpak repair`.
