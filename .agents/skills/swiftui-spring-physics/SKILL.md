---
name: swiftui-spring-physics
description: "Master organic spring physics, mass, stiffness, damping ratios, bounce curves, interruptible gesture retargeting, and continuous velocity handoff in SwiftUI."
---

# SwiftUI Spring Physics & Retargeting

Guide for tuning physical spring animations and building interruptible, gesture-driven motion.

## Standard Spring vs Interactive Spring

- **`.spring(response:dampingFraction:blendDuration:)`**: Settled state transitions. Higher damping (0.75 - 0.90) prevents unwanted oscillation.
- **`.interactiveSpring(response:dampingFraction:blendDuration:)`**: Direct manipulation (pan/drag). Lower response time (0.25 - 0.35s) for instant tracking.
- **`Wave` Retargetable Physics**: Preserves velocity vector when user redirects a gesture mid-flight.

## Reference Repositories in Codebase
- `references/animations/swiftui-spring-animations`: 100+ parameter recipes for bounce, wobble, and fluid settle.
- `references/animations/Wave`: High-performance interruptible physics engine with velocity handoff.
