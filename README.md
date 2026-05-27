# Links

A minimal macOS menubar-style app for organising bookmarks and app shortcuts, built with SwiftUI.

## Features

- **Link tree** — add root links or nested groups; expand/collapse with a click
- **App shortcuts** — a grid of software icons at the top for one-click app/URL launching
- **Drag-to-reorder** — rearrange both links and shortcuts by dragging
- **Persistent storage** — all data auto-saves to disk with a short debounce
- **Dark glass UI** — floating panel aesthetic, no title bar

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later

## Getting started

```sh
git clone https://github.com/<your-username>/Links.git
open Links.xcodeproj
```

Press **⌘R** to build and run.

## Project layout

```
Links/
├── LinksApp.swift       # App entry point, window style
└── ContentView.swift    # All views, models, and persistence logic
```

## Version history

| Version | Notes |
|---------|-------|
| 3.9a | UI zoom controls (header) |
| 3.8 | Clean stable UI system, seamless autosave, persistent icon storage |
| 3.6 | Stable rollback baseline |
| 2.7 | Larger software icons, tighter spacing |
| 2.6 | Drag reorder for links |
| 2.5 | Brighter main content background |
| 2.3 | Wrapping software icons, frame cleanup |
