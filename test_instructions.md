# Running WiggyWash locally (preview before pushing)

Run these from the project root: `/Users/aaronheiner/Documents/Sandbox/wiggywash`

## Quickest dev loop — run in Chrome with hot reload

```bash
flutter run -d chrome
```

A Chrome window opens with the app. Keep this terminal focused and use the key
commands after each edit:

- `r` → hot reload (applies code changes in ~1s, keeps current screen)
- `R` → hot restart (full restart — use after changing themes, startup logic, or assets)
- `q` → quit
- `h` → list all commands

> Tip: run this in Cursor's integrated terminal (`Ctrl+\``) so you can press `r`
> yourself. Asset changes (e.g. the help screenshots) need `R`, not just `r`.

## Run as a macOS desktop app

```bash
flutter run -d macos
```

## Preview the exact production web build (what actually deploys)

```bash
flutter build web && python3 -m http.server 8000 --directory build/web
```

Then open http://localhost:8000

## Handy checks

```bash
flutter devices    # list devices you can run on
flutter analyze    # check for errors/lints before pushing
```
