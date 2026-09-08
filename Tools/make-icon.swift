#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Composes artwork onto a square, opaque app icon.
//
// iOS icons cannot carry an alpha channel and are always square, so a wide mark has to
// be placed on a solid ground rather than simply resized. The mark is fitted inside a
// margin so it still reads at the size a home screen actually renders it.

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    print("usage: make-icon.swift <source-image> <output.png> [size] [inset-fraction] [background-hex]")
    exit(1)
}

let sourcePath = arguments[1]
let outputPath = arguments[2]
let size = arguments.count > 3 ? Int(arguments[3]) ?? 1024 : 1024
let inset = arguments.count > 4 ? Double(arguments[4]) ?? 0.16 : 0.16
let backgroundHex = arguments.count > 5 ? arguments[5] : "000000"

func color(fromHex hex: String) -> (Double, Double, Double) {
    var value: UInt64 = 0
    Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
    return (
        Double((value >> 16) & 0xFF) / 255,
        Double((value >> 8) & 0xFF) / 255,
        Double(value & 0xFF) / 255
    )
}

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: sourcePath) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    print("error: could not read \(sourcePath)")
    exit(1)
}

/// Finds the artwork inside the source, ignoring the flat ground around it.
///
/// A mark exported with generous margins would otherwise be fitted as if the margins
/// were part of it, leaving it small on the home screen. Trimming first means the inset
/// below is measured against the artwork itself.
func trimmedRect(of image: CGImage, threshold: Int = 40) -> CGRect {
    let width = image.width
    let height = image.height
    guard let data = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return CGRect(x: 0, y: 0, width: width, height: height) }

    data.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let pixels = data.data else {
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
    let buffer = pixels.bindMemory(to: UInt8.self, capacity: width * height * 4)

    var minX = width, minY = height, maxX = -1, maxY = -1
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            let luminance = (Int(buffer[offset]) * 299
                + Int(buffer[offset + 1]) * 587
                + Int(buffer[offset + 2]) * 114) / 1000
            // Anything meaningfully brighter than the ground counts as artwork.
            if luminance > threshold {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
    }

    guard maxX >= minX, maxY >= minY else {
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

let cropRect = trimmedRect(of: image)
let artwork = image.cropping(to: cropRect) ?? image
print("trimmed \(image.width)x\(image.height) to \(Int(cropRect.width))x\(Int(cropRect.height))")

guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    // No alpha: the App Store rejects an icon that has one.
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    print("error: could not create the drawing context")
    exit(1)
}

let (red, green, blue) = color(fromHex: backgroundHex)
context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Fit the artwork inside the margin, keeping its proportions.
let available = Double(size) * (1 - inset * 2)
let scale = min(available / Double(artwork.width), available / Double(artwork.height))
let drawnWidth = Double(artwork.width) * scale
let drawnHeight = Double(artwork.height) * scale

context.interpolationQuality = .high
context.draw(
    artwork,
    in: CGRect(
        x: (Double(size) - drawnWidth) / 2,
        y: (Double(size) - drawnHeight) / 2,
        width: drawnWidth,
        height: drawnHeight
    )
)

guard let output = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: outputPath) as CFURL, UTType.png.identifier as CFString, 1, nil
      ) else {
    print("error: could not write \(outputPath)")
    exit(1)
}

CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else {
    print("error: could not finalize \(outputPath)")
    exit(1)
}

print("wrote \(outputPath) at \(size)x\(size), artwork \(Int(drawnWidth))x\(Int(drawnHeight))")
