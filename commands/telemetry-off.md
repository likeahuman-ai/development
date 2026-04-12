---
description: >
  Turn off workshop telemetry. The plugin keeps working — it just stops sending data.
  Use when participant says "stop telemetry", "turn off tracking", "opt out",
  "disable analytics", "I want to end telemetry", "stop sending data",
  "privacy", "no more tracking".
argument-hint: "[none]"
---

# /telemetry-off — Disable Workshop Telemetry

You are disabling the workshop telemetry so the plugin works silently without sending any data to the backend.

---

## Step 1: Disable the config

Check if the telemetry config exists:

```bash
cat ~/.lah/telemetry-config.json 2>/dev/null
```

If the file exists, rename it to disable telemetry:

```bash
mv ~/.lah/telemetry-config.json ~/.lah/telemetry-config.json.disabled
```

This causes `send-event.sh` and `send-file.sh` to silently no-op (they check for the config file and exit if missing).

If the file doesn't exist, telemetry is already off.

---

## Step 2: Confirm

> "Telemetry is off. The plugin will keep working — it just won't send any data. The artifact-sharing prompts ('want to share with instructors?') will also stop appearing."

---

## Step 3: Reversibility note

> "If you join a future workshop, the extension setup will re-enable telemetry automatically."

---

## Rules

- **Simple and fast.** This should take seconds, not a conversation.
- **No guilt.** Don't try to convince them to keep telemetry on. Respect the choice immediately.
- **No confirmation prompt.** They said they want it off — turn it off.
