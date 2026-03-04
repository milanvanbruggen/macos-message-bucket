# Message Bucket — Vibe Spec

## Purpose

A macOS menu bar app that serves as a central inbox for scheduled messages from Claude Cowork and other automation tools. Messages arrive as JSON files dropped into a watched folder, and the app notifies the user at the scheduled time.

---

## Platform

- **OS**: macOS
- **UI language**: English
- **Runs as**: Menu bar app (no Dock icon)
- **Auto-start**: Launches on system boot, always runs in the background

---

## Message Format (JSON)

Each message is a `.json` file placed in the watched inbox folder.

```json
{
  "id": "unique-string-or-uuid",
  "title": "Max 25 characters",
  "body": "Full message text. **Markdown** is supported.",
  "scheduled_at": "2026-03-04T09:00:00+01:00",
  "source": "Claude Cowork"
}
```

| Field          | Type     | Required | Notes                              |
|----------------|----------|----------|------------------------------------|
| `id`           | string   | Yes      | Unique identifier, prevents duplicates |
| `title`        | string   | Yes      | Max 25 characters, shown in menu bar list |
| `body`         | string   | Yes      | Full message, Markdown supported, sender determines formatting |
| `scheduled_at` | ISO 8601 | Yes      | When to trigger the notification   |
| `source`       | string   | No       | Who sent the message (e.g. "Claude Cowork") |

---

## File & Folder Structure

```
~/Message Bucket/          (user-configurable path)
├── inbox/                 ← watched folder for incoming JSON files
└── archive/               ← read messages are moved here automatically
```

- The app uses **FSEvents** to watch the inbox folder in real time.
- When a JSON file is added, it is parsed and scheduled.
- When a message is marked as **Read**, its JSON file is moved to `archive/`.
- The watched folder path is configurable in Settings.

---

## Notification Behavior

### Default behavior
Every incoming message triggers **two things simultaneously**:
1. A **prominent overlay** (see below)
2. An **unread badge** on the menu bar icon

### Prominent overlay
- Centered horizontally and vertically on screen
- Background behind overlay is **blurred**
- Follows **Apple Human Interface Guidelines** for styling
- Displayed **above all other windows**
- Contains:
  - Message title
  - Full message body (rendered Markdown)
  - Two action buttons: **Read** and **Snooze**
- **Escape key** = Snooze

### Snooze behavior
- The prominent overlay is dismissed
- The message remains in the unread count (badge stays active)
- No further overlay is shown for this message unless reopened manually

### Read behavior
- The message is removed from the unread count
- Its JSON file is moved to `archive/`

### Focus Mode
- By default, notifications **override Focus modes** (equivalent to macOS Critical Alerts)
- A setting allows the app to **follow Focus modes** instead

---

## Menu Bar Icon

- Displays an **unread badge** with the count of unread messages when there are unread messages
- Clicking the icon opens a **dropdown panel** containing:

### Dropdown contents
1. **Unread messages** — list of messages not yet marked as Read
2. **Read messages** — list of archived messages (read-only)
3. **Settings** — opens the Settings window
4. **Quit** — closes the application

### Message item in the list
Each message in the dropdown shows:
- **Title** (max 25 characters)
- **Timestamp** (when the message was received/scheduled)

Clicking a message opens the **prominent overlay** for that message.

---

## Settings

| Setting | Default | Description |
|---|---|---|
| Prominent overlay | On | Show the full-screen overlay for new messages |
| Follow Focus modes | Off | When off, notifications override macOS Focus/DND |
| Inbox folder | `~/Message Bucket/inbox` | Path the app watches for new JSON files |

---

## Out of Scope (v1)

- Syncing between devices
- Sending or composing messages from within the app
- User accounts or authentication
- Multiple inbox folders
- Per-message notification type overrides
- Timed snooze (e.g. "remind me in 15 minutes")
