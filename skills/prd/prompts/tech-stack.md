# Preferred Tech Stack

The workshop uses a preferred tech stack. Default to this unless the participant's idea genuinely can't work with it.

## Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Framework | Next.js | Full-stack React, file-based routing, server components |
| Backend | Convex | Real-time database, no API layer to write, type-safe queries |
| Styling | Tailwind CSS | Utility-first, no CSS files to manage, rapid prototyping |
| Component dev | Storybook | Visual component development, isolated testing |

## Rules

- **Default to this stack.** If the participant says "I want to build a web app", use this stack. Don't present alternatives unless there's a reason.
- **Extend freely.** Additional libraries are added on top as needed — auth (Clerk, NextAuth), payments (Stripe), charts (Recharts), maps (Leaflet), icons (Lucide), etc.
- **Override with reason.** If the participant specifically wants a different stack (Vue, Python, plain HTML) or their idea can't work with this one (mobile app, CLI tool, game), respect that. Note the chosen stack in the PRD and move on. Don't argue or push back.
- **Version check still applies.** Run `npm view` for each package to ensure you're recommending the latest stable versions.

## When to Override

This stack doesn't fit when:
- The project is not a web application (CLI tools, mobile apps, desktop apps, games)
- The participant has strong existing experience with a different stack and wants to use it
- The project has specific requirements that conflict (e.g., needs server-side rendering with a specific backend framework)

When overriding, always note the alternative stack in the PRD's Architecture section with a brief reason.
