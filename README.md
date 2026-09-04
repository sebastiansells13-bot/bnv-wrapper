# BNV Wrapper

A tiny native macOS app that opens https://bnv-app.vercel.app in its own
window (via WKWebView), so it behaves like a real app.

It does NOT bundle any of the BNV app's code — it always loads the live
site, so it's automatically up to date with whatever's deployed on Vercel.

## Features

- Own Dock icon, own window, Cmd+Q quits
- Cmd+R reload, Cmd+[ / Cmd+] back/forward, Cmd+=/Cmd+-/Cmd+0 zoom
- Copy/paste works in forms
- File exports (CSV/PDF/etc.) trigger a native Save dialog instead of
  silently doing nothing
- Links/buttons that open a new tab or popup (e.g. Instagram/eBay sign-in)
  open in their own window, sharing the same session/cookies; once that
  flow redirects back to the BNV domain, the popup auto-closes and the
  main window refreshes
- Camera access works if any page asks for it (you'll get the normal
  macOS camera permission prompt the first time)
- Right-click → "Inspect Element" opens WebKit's inspector for debugging

## Build it

Requires Xcode Command Line Tools (if you don't have them: `xcode-select --install`).

```
./build.sh
```

This produces `BNV.app` in this same folder. Double-click it, or drag it to
/Applications.

## Custom icon

Drop a square PNG named `icon.png` (ideally 1024x1024) in this folder, then
run `./build.sh` again to bake it in as the app icon.

## Files

- `src/main.swift` — the whole app (AppKit + WebKit)
- `Info.plist` — app metadata + camera/mic usage descriptions
- `build.sh` — compiles main.swift, bakes in the icon, ad-hoc signs, assembles BNV.app
- `icon.png` — source image for the app icon
