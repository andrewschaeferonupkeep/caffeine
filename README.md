# Caffeine

A tiny macOS menu bar app that wraps the built-in `caffeinate` command. Click the cup in your menu bar to keep your Mac awake, and pick which `caffeinate` options to use.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

## Features

- One-click on/off switch (filled cup = awake, outline = off)
- Checkboxes for every assertion flag:
  - `-d` prevent display sleep
  - `-i` prevent system idle sleep
  - `-m` prevent disk idle sleep
  - `-s` prevent system sleep (AC power only)
  - `-u` declare the user is active
- Duration (`-t`): indefinitely, 15m–8h presets, or a custom number of minutes, with a live countdown
- Advanced:
  - Wait for PID (`-w`): stay awake until a given process exits
  - Run a command: stay awake until the command finishes
- Floating overlay showing elapsed session time and active settings (draggable, with a stop button; right-click to hide or turn off)
- Live preview of the exact `caffeinate` command being run
- Settings persist across restarts; changing an option while running restarts `caffeinate` with the new options
- `caffeinate` is tied to the app's process, so it never keeps running after the app quits or crashes
- Launch at login

## Install

Requires macOS 13+ and the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/andrewschaeferonupkeep/caffeine.git
cd caffeine
./build.sh --install   # builds, copies to /Applications, and launches
```

Or run `./build.sh` to just build `build/Caffeine.app`.

The app is ad-hoc signed. If macOS blocks it the first time, right-click the app and choose **Open**.

## Contributing

`main` is protected: open a pull request and it needs approval from the code owner before it can merge.
