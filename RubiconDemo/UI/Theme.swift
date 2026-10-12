import SwiftUI

/// The Rubicon palette of the Android demo: a light sky blue, a slate blue and a teal accent.
enum Theme {
    static let sky = Color(red: 0x2E / 255, green: 0x7C / 255, blue: 0xF6 / 255)
    static let skyContainer = Color(red: 0xDC / 255, green: 0xE9 / 255, blue: 0xFF / 255)
    static let slate = Color(red: 0x4F / 255, green: 0x6B / 255, blue: 0x92 / 255)
    static let teal = Color(red: 0x00 / 255, green: 0x89 / 255, blue: 0x7B / 255)
    static let paper = Color(red: 0xF6 / 255, green: 0xF9 / 255, blue: 0xFE / 255)
    static let card = Color.white
    static let ink = Color(red: 0x15 / 255, green: 0x1C / 255, blue: 0x27 / 255)
    static let muted = Color(red: 0x46 / 255, green: 0x53 / 255, blue: 0x6A / 255)
    static let outline = Color(red: 0xC9 / 255, green: 0xD3 / 255, blue: 0xE2 / 255)
    static let success = Color(red: 0x2E / 255, green: 0x9E / 255, blue: 0x62 / 255)
    static let warning = Color(red: 0xE0 / 255, green: 0x9B / 255, blue: 0x1B / 255)
    static let danger = Color(red: 0xD6 / 255, green: 0x45 / 255, blue: 0x45 / 255)
}
