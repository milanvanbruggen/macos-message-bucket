# Message Bucket

A macOS menu bar app that acts as a central inbox for scheduled messages from Claude Cowork and other automation tools. Messages arrive as JSON files dropped into a watched folder and are delivered as prominent overlays at the scheduled time.

## Overview

Message Bucket runs quietly in your menu bar with no Dock icon. Drop a JSON file into the inbox folder, and the app will queue it, deliver it at the scheduled time, and let you snooze or archive it — all reflected in the filesystem.

## Features

- **Scheduled delivery** — messages are shown at their `scheduled_at` time, not when the file is dropped
- **Folder-based state** — message state is reflected in the filesystem (queue / snoozed / archive)
- **Prominent overlay** — full-screen blurred overlay shown above all other windows
- **Menu bar badge** — shows unread + snoozed count; clears only when marked as Read
- **Snooze** — dismiss the overlay without marking as read; message stays in the badge count
- **Archive view** — read messages are hidden behind an Archive button, keeping the inbox clean
- **Persistent state** — queue and snoozed messages are restored when the app restarts
- **Configurable folder** — the base folder can be changed in Settings

## Requirements

- macOS 13.0 or later
- Xcode 15+ (Swift 6)

## Installation

```bash
# Clone the repository
git clone https://github.com/milanvanbruggen/macos-message-bucket.git
cd macos-message-bucket

# Generate the Xcode project (requires xcodegen)
xcodegen generate

# Open in Xcode
open MessageBucket.xcodeproj
```

Build and run the target. The app will appear in your menu bar.

## Folder Structure

The app manages four subfolders inside your configured base directory:

```
~/Message Bucket/
├── inbox/      ← Drop JSON files here
├── queue/      ← Scheduled messages waiting for delivery
├── snoozed/    ← Messages the user has snoozed
└── archive/    ← Messages marked as Read
```

Files move automatically between these folders as messages change state.

## Message Format

Each message is a `.json` file placed in the `inbox/` folder:

```json
{
  "id": "unique-id",
  "title": "Short title (max 25 chars)",
  "body": "Full message body. **Markdown** is supported.",
  "scheduled_at": "2026-03-04T09:00:00+01:00",
  "source": "Claude Cowork"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | ✅ | Unique identifier, prevents duplicates |
| `title` | string | ✅ | Shown in menu bar list (max 25 chars) |
| `body` | string | ✅ | Full message, Markdown supported |
| `scheduled_at` | ISO 8601 | ✅ | When to trigger the notification |
| `source` | string | ❌ | Sender label (e.g. "Claude Cowork") |

## Message Lifecycle

```
inbox/
  ├── scheduled_at in the future → queue/  (no badge yet)
  └── scheduled_at in the past  → delivered immediately (badge++)

queue/
  └── timer fires at scheduled_at → overlay shown (badge++)

Overlay actions:
  ├── Snooze → snoozed/  (badge stays)
  └── Read   → archive/  (badge--)
```

## Settings

Open Settings from the menu bar dropdown:

| Setting | Default | Description |
|---|---|---|
| Show prominent overlay | On | Full-screen overlay on delivery; if off, only the badge updates |
| Follow Focus modes | Off | When on, overlays are suppressed during macOS Focus/DND |
| Message Bucket folder | `~/Message Bucket` | Base folder; all subfolders are created automatically |

## Architecture

| File | Responsibility |
|---|---|
| `AppDelegate.swift` | App lifecycle, wiring all components together |
| `FileWatcher.swift` | Polls inbox every 2 seconds; manages all folder moves |
| `NotificationScheduler.swift` | Schedules `Timer` per message, fires `onDeliver` at the right time |
| `MessageStore.swift` | In-memory state: unread, snoozed, archived |
| `AppSettings.swift` | User preferences, persisted in `UserDefaults` |
| `MenuBarView.swift` | Dropdown popover with Unread / Snoozed / Archive sections |
| `OverlayView.swift` | Full-screen SwiftUI overlay with blur effect |
| `OverlayWindowController.swift` | `NSWindow` at `.screenSaver` level, shown above all other windows |

## Sending a Test Message

```bash
cat > ~/Message\ Bucket/inbox/hello.json << 'EOF'
{
  "id": "hello-001",
  "title": "Hello 👋",
  "body": "This is a **test message** from Message Bucket.",
  "scheduled_at": "2026-03-04T10:00:00+01:00",
  "source": "Manual Test"
}
EOF
```

Set `scheduled_at` to a time in the near future to test the queue flow, or in the past to trigger delivery immediately.

## License

MIT
