# Actual — design reference for Claude Code

This folder is meant to sit inside the Xcode project repo, next to `actual-app-concept.md`, so a local Claude Code session can read the actual layout, colors, and spacing while writing the SwiftUI views instead of guessing from a description.

## What's in here

`screens/` holds one plain, standalone HTML file per screen, numbered in app flow order. Each one opens directly in a browser and is just inline styled divs, no build step, no framework of its own, so it doubles as a literal spec, exact hex colors, exact font sizes, exact padding, exact border radius, all sitting right in the markup.

`previews/` holds a PNG render of each screen, same numbering, for a quick visual look without opening every file.

## Why HTML instead of the published canvas link

The live canvas link is a full visual editor wrapped around the design, useful for looking at and tweaking the screens by hand, but not a clean thing to hand a coding agent. These exported files are the opposite, no editor, no extra markup, just the screen itself, which is what actually helps when asking Claude Code to translate a layout into SwiftUI.

## Design tokens used throughout

```
background      #141414
card            #1e1e1e
ink (primary)   #f2f0ec
ink, soft       #a8a49c
ink, faint      #68645c
accent          #f2f0ec  (same as ink, used for emphasis, progress, selection)
line / border   rgba(255,255,255,0.07)
font            Inter, weights 400 / 500 / 600 / 700
```

Phone frames are 390 by 844. The Apple Watch screen is a 198 by 242 face inside a 264 by 320 canvas. The Mac menu bar mockup is 520 by 360. The landing page is a 1440 wide flowing page.

## Screens

1. Onboarding, mark, the quiet opening screen
2. Onboarding, tagline, "Know your time."
3. Home
4. Estimate capture
5. Session active
6. Session end
7. Insights
8. Gap filler suggestion
9. Shared reminder, send
10. Shared reminder, receive
11. Shared reminder, in-app prompt
12. Apple Watch, active session
13. macOS menu bar companion
14. Landing page

## Suggested prompt for Claude Code

"Read actual-app-concept.md for the product and feature specs, and design-reference/screens for the exact visual design, colors, spacing, and layout of each screen. Build the SwiftUI views to match these as closely as SwiftUI allows, using the tokens listed in design-reference/README.md rather than inventing new ones."
