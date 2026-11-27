import SwiftUI
import UIKit

// MARK: - Resource-backed palette

enum UntisPalette {
    static let brand = Color(hex: "#FF6033")
    static let navy = Color(hex: "#26396A")
    static let surface = adaptive(light: "#FFFFFF", dark: "#1C1C1E")
    static let timetableBackground = adaptive(light: "#F5F5F5", dark: "#000000")
    static let timegridBackground = adaptive(light: "#FFFFFF", dark: "#161616")
    static let title = adaptive(light: "#414D55", dark: "#F3F5F7")
    static let subtitle = adaptive(light: "#67747E", dark: "#8A96A1")
    static let text = adaptive(light: "#8A96A1", dark: "#BFC8CF")
    static let navigationTint = adaptive(light: "#8A96A1", dark: "#67747E")
    static let navigationSubtitle = adaptive(light: "#919DA6", dark: "#67747E")
    static let separator = adaptive(light: "#DCDFE5", dark: "#414D55")
    static let gridLine = adaptive(light: "#E7E9EC", dark: "#303438")

    // Untis dark-mode lesson cards are slate, not pastel subject-colour fills.
    // Subject colours remain as the narrow leading accent.
    static let lessonBackground = adaptive(light: "#EEF1F3", dark: "#333E47")
    static let lessonBorder = adaptive(light: "#D3D9DE", dark: "#414D55")
    static let lessonTitle = adaptive(light: "#414D55", dark: "#D5DADF")
    static let lessonSubtitle = adaptive(light: "#687680", dark: "#C2CAD0")

    static let cancelledBackground = adaptive(light: "#FFF3F3", dark: "#81002E")
    static let cancelledBorder = adaptive(light: "#DF0047", dark: "#F03164")
    static let cancelledText = adaptive(light: "#7A1831", dark: "#FFE5EC")
    static let changeBackground = adaptive(light: "#E4FFF3", dark: "#005741")
    static let changeBorder = adaptive(light: "#00926D", dark: "#21C0A0")
    static let examBackground = adaptive(light: "#FFF7D9", dark: "#6C2B0B")
    static let examBorder = adaptive(light: "#9F532D", dark: "#FFB728")

    private static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hexString: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension LessonStatus {
    /// Border / accent colour used for this status in the grid and the detail screen.
    var accent: Color {
        switch self {
        case .normal: return UntisPalette.brand
        case .cancelled: return UntisPalette.cancelledBorder
        case .roomChange, .substitution: return UntisPalette.changeBorder
        case .exam: return UntisPalette.examBorder
        }
    }

    var fill: Color {
        switch self {
        case .normal: return UntisPalette.lessonBackground
        case .cancelled: return UntisPalette.cancelledBackground
        case .roomChange, .substitution: return UntisPalette.changeBackground
        case .exam: return UntisPalette.examBackground
        }
    }
}

// MARK: - Colour helpers

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hexString: hex))
    }

    func darker(by amount: CGFloat) -> Color {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return Color(red: max(0, red - amount), green: max(0, green - amount), blue: max(0, blue - amount), opacity: alpha)
    }
}

extension UIColor {
    convenience init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        if cleaned.count == 8 {
            alpha = CGFloat((value >> 24) & 0xFF) / 255
            red = CGFloat((value >> 16) & 0xFF) / 255
            green = CGFloat((value >> 8) & 0xFF) / 255
            blue = CGFloat(value & 0xFF) / 255
        } else {
            alpha = 1
            red = CGFloat((value >> 16) & 0xFF) / 255
            green = CGFloat((value >> 8) & 0xFF) / 255
            blue = CGFloat(value & 0xFF) / 255
        }
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - Icons (bundled Untis artwork, with an SF Symbol fallback if an image is missing)

struct UntisIcon: View {
    let asset: String
    let symbol: String
    var template: Bool = true

    var body: some View {
        if UIImage(named: asset) != nil {
            Image(asset)
                .resizable()
                .renderingMode(template ? Image.TemplateRenderingMode.template : Image.TemplateRenderingMode.original)
                .scaledToFit()
        } else {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
        }
    }
}

// MARK: - Liquid Glass with a material fallback for iOS 16–25 (navigation chrome only)

struct UntisLiquidGlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.22), radius: 13, x: 0, y: 5)
        }
    }
}

// MARK: - Cached date formatters

enum UntisFormat {
    static let weekdayShort = make("EEE")
    static let monthShort = make("MMM")
    static let dayMonth = make("d MMM")
    static let fullDate = make("EEEE, d MMMM yyyy")

    private static func make(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = format
        return formatter
    }
}
