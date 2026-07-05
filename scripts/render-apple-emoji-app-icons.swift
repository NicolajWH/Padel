#!/usr/bin/env swift
import AppKit
import Foundation

let emoji = "🎾"
let iconSize = 1024
let outputPaths = [
    "iOS/PadelApp/Assets.xcassets/AppIcon.appiconset/icon-1024.png",
    "WatchApp/PadelWatch/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
]

func renderIcon(to path: String) throws {
    let size = NSSize(width: iconSize, height: iconSize)
    let image = NSImage(size: size)

    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center

    let font = NSFont(name: "Apple Color Emoji", size: 760) ?? NSFont.systemFont(ofSize: 760)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .paragraphStyle: paragraphStyle
    ]

    let attributedEmoji = NSAttributedString(string: emoji, attributes: attributes)
    let emojiSize = attributedEmoji.size()
    let drawRect = NSRect(
        x: 0,
        y: (size.height - emojiSize.height) / 2 - 8,
        width: size.width,
        height: emojiSize.height
    )
    attributedEmoji.draw(in: drawRect)

    image.unlockFocus()

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "RenderAppleEmojiAppIcons", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not encode rendered app icon as PNG."
        ])
    }

    try FileManager.default.createDirectory(
        atPath: URL(fileURLWithPath: path).deletingLastPathComponent().path,
        withIntermediateDirectories: true
    )
    try pngData.write(to: URL(fileURLWithPath: path), options: .atomic)
    print("Rendered \(path)")
}

for path in outputPaths {
    try renderIcon(to: path)
}
