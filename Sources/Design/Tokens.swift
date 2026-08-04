import SwiftUI

/// Design tokens. Everything downstream styles from here and nothing hard-codes a value.
///
/// DIRECTION: "Chair-side"
///
/// The chrome behaves like good salon lighting: present, warm, never the subject. The
/// person in the chair is the subject, and every pixel we draw is competing with their
/// face for attention.
///
/// What this direction refuses, and why:
///
///   - No gradients, no glow, no soft pastel. That is the beauty-app register, and it
///     reads as a toy filter. A stylist charging for a consultation cannot be holding a
///     toy. Every competitor examined sits in that register, which is why we are not.
///   - No pure white and no pure black. Salon light is tungsten-warm; neutral greys go
///     blue against it and look like a different device.
///   - No colour used decoratively. Brass means "the system is working". Clay means
///     "this destroys something". A third meaning would dilute both.
///
/// Type runs larger than an iPhone app normally would, because the stylist reads this at
/// arm's length across a chair while talking to somebody. Anything set at 11pt is set for
/// a person holding the phone, and half our users are not holding it.
enum Tokens {

    // MARK: - Colour

    enum Colour {
        /// Behind everything. Near-black, warmed slightly, so chrome reads as shadow
        /// falling across the camera feed rather than as a panel bolted on top.
        static let base = Color(red: 0.043, green: 0.043, blue: 0.047)

        /// Floating surfaces over live video. Deliberately low alpha: the face beneath
        /// must stay legible, because the face is the product.
        static let surface = Color.white.opacity(0.08)
        static let surfaceRaised = Color.white.opacity(0.14)
        static let hairline = Color.white.opacity(0.16)

        /// Warm tungsten, borrowed from salon lighting. The single accent, and it has
        /// exactly one meaning: the system has hold of the face.
        static let brass = Color(red: 0.784, green: 0.635, blue: 0.392)

        /// Destructive. Ending a session is a biometric control (ADR-005), not a
        /// navigation transition, and it is coloured like it means it.
        static let clay = Color(red: 0.769, green: 0.341, blue: 0.247)

        /// Warm off-white. Pure white glares against a camera feed at salon brightness.
        static let ink = Color(red: 0.961, green: 0.949, blue: 0.937)
        static let inkMuted = Color(red: 0.659, green: 0.635, blue: 0.604)
        static let inkFaint = Color(red: 0.435, green: 0.420, blue: 0.404)

        /// Scrim under chrome sitting over live video, so text survives a bright window
        /// behind the customer. Salons have big windows.
        static let scrim = Color.black.opacity(0.55)
    }

    // MARK: - Type
    //
    // Read at arm's length across a chair, not at phone distance. Every size is a step
    // larger than the equivalent would be in a normal consumer app.

    enum Typography {
        static func display(_ t: String) -> Text {
            Text(t).font(.system(size: 34, weight: .medium)).tracking(-0.6)
        }
        static func title(_ t: String) -> Text {
            Text(t).font(.system(size: 24, weight: .medium)).tracking(-0.3)
        }
        static func body(_ t: String) -> Text {
            Text(t).font(.system(size: 17, weight: .regular))
        }
        static func label(_ t: String) -> Text {
            Text(t).font(.system(size: 15, weight: .medium))
        }
        /// Small caps for category tabs and state. Tracking is wide because uppercase at
        /// small size closes up and stops being scannable in peripheral vision, which is
        /// where the stylist is reading it from.
        static func micro(_ t: String) -> Text {
            Text(t.uppercased()).font(.system(size: 12, weight: .semibold)).tracking(1.1)
        }
    }

    // MARK: - Space, radius, motion

    enum Space {
        static let hair: CGFloat = 2
        static let tight: CGFloat = 6
        static let snug: CGFloat = 10
        static let base: CGFloat = 16
        static let loose: CGFloat = 24
        static let wide: CGFloat = 36
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 14
        static let large: CGFloat = 22
        static let pill: CGFloat = 999
    }

    enum Motion {
        /// Nothing bounces. A spring that overshoots reads as playful, and this is a
        /// person being told what they will look like.
        static let calm = Animation.easeOut(duration: 0.22)
        static let settle = Animation.easeInOut(duration: 0.35)
    }

    /// Chrome must never cover more than this much of the frame. The camera is the
    /// product; every control is a tax on it. Tracked as a number so it can be argued
    /// with rather than eroded silently, one control at a time.
    static let maxChromeFraction: Double = 0.28
}
