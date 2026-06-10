# MyPace

> An invisible teleprompter for video creators on macOS.

[![version](https://img.shields.io/badge/version-1.0.0-blueviolet)](https://github.com/AidenNovak/mypace/releases) [![platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)]() [![build](https://img.shields.io/badge/build-swiftc%20%2B%20shell-lightgrey)]()

Record your natural delivery once. MyPace captures your rhythm, pauses, and pacing — then plays it back with word-by-word highlighting while staying completely invisible to screen recording.

---

## Features

- **Hidden from screen recording** — `NSWindow.sharingType = .none` makes the window invisible to OBS, QuickTime, Loom, Zoom
- **Speech-first workflow** — Talk naturally. AI turns your speech into a rhythm-aware script with per-character timestamps
- **Character-level playback** — Each character has its own timestamp. Current word subtly scales up
- **Script editor** — Full editor with sidebar, dark theme, rhythm status indicators
- **Screen capture toggle** — One-click toolbar button to allow screen capture for demos
- **3 languages** — Simplified Chinese, English, Japanese with auto-detect
- **Privacy by default** — All data stays on your Mac. Never uploaded

## Download

[Download v1.0.0 DMG](https://github.com/AidenNovak/mypace/releases/latest) · Apple Silicon · macOS 14+

The DMG includes a bundled ASR credential — **zero configuration needed**. Just install and start talking.

## Building from Source

```bash
cd app
./build-app.sh
open "build/MyPace Preview.app"
```

**Note:** The open-source repo does **not** include ASR credentials. To use ASR features with a self-built version, configure your own Volcano Engine credentials in Preferences → Speech Recognition, or set them in the app's Preferences panel.

You'll need:
- macOS 14+, Xcode Command Line Tools (`xcode-select --install`)
- A Volcano Engine account with ASR access (App ID + Access Token)

## How It Works

1. **Record** — Tap the red button and speak naturally into your mic
2. **AI processes** — ASR generates a script with per-character timestamps (5–10 sec)
3. **Play** — Tap play. The teleprompter scrolls at your exact pace with word-by-word highlighting
4. **Record your video** — Open any screen recorder. MyPace stays invisible

## Tech Stack

| Layer | Choice |
|---|---|
| UI | Swift + AppKit + CoreAnimation |
| Recording | AVAudioRecorder (16 kHz mono WAV) |
| ASR | Volcano Engine v3 (per-character timestamps) |
| Character rendering | CATextLayer per character |
| Screen capture invisibility | `NSWindow.sharingType = .none` |
| Storage | JSON (`~/Library/Application Support/MyPacePreview/`) |
| i18n | Pure Swift dictionary, no `.strings` files |
| Build | `xcrun swiftc` + `codesign` + `hdiutil` |

## Repo Structure

```
mypace/
├── app/                    App source code
│   ├── Preview/              14 Swift files
│   ├── Resources/            AppIcon.icns
│   └── build-app.sh          Build script → .app + .dmg
├── site/                   Landing page (Cloudflare Pages)
└── README.md
```

## Privacy

- Audio is sent to ASR provider for speech-to-text processing only
- Scripts, rhythm maps, and recordings are stored only on your Mac
- No analytics, no crash reporting, no cloud storage
- Delete everything: `rm -rf ~/Library/Application\ Support/MyPacePreview/`

## License

All rights reserved. Source available for inspection.
