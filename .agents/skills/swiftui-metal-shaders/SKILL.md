---
name: swiftui-metal-shaders
description: "Implement GPU-accelerated Metal shaders in SwiftUI using iOS 17+ ShaderLibrary, .colorEffect(), .distortionEffect(), and .layerEffect(). Use for liquid glass, neon glow, holographic foil, glitch, ripple, chromatic aberration, and noise visual effects."
---

# SwiftUI Metal Shaders

Create high-performance GPU-driven visual effects in SwiftUI using the modern `ShaderLibrary` APIs introduced in iOS 17+.

## Modern SwiftUI Shader APIs

```swift
import SwiftUI

// 1. Color Effect: Transforms pixel colors
view.colorEffect(ShaderLibrary.neonGlow(.float(intensity), .color(tintColor)))

// 2. Distortion Effect: Displaces pixel positions (waves, ripples, water)
view.distortionEffect(
    ShaderLibrary.waterRipple(.float2(size), .float(time), .float(amplitude)),
    maxSampleOffset: CGSize(width: 20, height: 20)
)

// 3. Layer Effect: Samples surrounding pixels (blur, glass refraction, glow)
view.layerEffect(
    ShaderLibrary.liquidGlass(.float(refractionIndex), .float(time)),
    maxSampleOffset: CGSize(width: 30, height: 30)
)
```

## Reference Repositories in Codebase
- `references/animations/SwiftUIShaders`: 41+ production modifiers (hologram, glitch, foil, light sweeps).
- `references/animations/SwiftShaders`: Drop-in `.glitch()`, `.neonGlow()`, `.chromaticAberration()` modifiers.
