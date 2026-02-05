# CARINA Color System

This is the single source of truth for all CARINA OS visual elements. No colors should be introduced without updating this file.

## Core Background

| Name | Hex | Usage |
|------|-----|-------|
| Carina Void | #050814 | Primary background, deep space |
| Carina Abyss | #0A0F2A | Panels, windows, secondary background |

## Primary Gradients

| Name | Hex | Usage |
|------|-----|-------|
| Carina Indigo | #2B2F77 | Structure, depth |
| Carina Electric Blue | #1FA2FF | Navigation, calm actions |

## Energy Accents

| Name | Hex | Usage |
|------|-----|-------|
| Carina Magenta | #B14CFF | Energy, alerts, AI indicators |
| Carina Cyan | #3DE8FF | Action, active states |

## Utility

| Name | Hex | Usage |
|------|-----|-------|
| Carina Text Primary | #E6ECFF | Primary text |
| Carina Text Muted | #9AA3C7 | Secondary text, hints |
| Carina Divider | #1C2340 | Borders, separators |

## Rules

**No pure black. No pure white.** Everything lives in the "space light" range.

### Semantic Color Usage

- **Cyan** = action / active
- **Magenta** = energy / alert / AI
- **Blue** = navigation / calm
- **Indigo** = structure
- **No red** unless critical error
- **No green** unless explicit success

### Gradient Rules

- Gradients only left-to-right or radial
- Never use vertical gradients
- Primary gradient: Carina Indigo to Carina Electric Blue

## CLI/Terminal Colors

| Element | Color |
|---------|-------|
| Background | Carina Void (#050814) |
| Prompt accent | Carina Cyan (#3DE8FF) |
| Errors | Carina Magenta (#B14CFF) |
| Success | Carina Cyan (#3DE8FF) |
| Warnings | Carina Electric Blue (#1FA2FF) |
| Text | Carina Text Primary (#E6ECFF) |

### Prompt Style

```
carina@hostname >
```

Clean. Calm. No rainbow colors.

## GUI Theming (Sprint 1)

Sprint 1 GUI theming is limited to:
- GNOME default dark mode
- Custom wallpaper (branding/wallpapers/carina-void.png)
- Accent color if supported

No custom GTK themes, icons, or HUD elements in Sprint 1.

## Future Sprints

Later sprints will add:
- CARINA GTK theme (built on Adwaita)
- Mission Control UI using these tokens
- Sandbox UI panels
- Installer visuals
