import SwiftUI

// The domain components, styled from Tokens only. Each is written so it survives being
// nearly empty, because a component that only holds together in the full case is not
// finished. In this product the sparse case is not an edge case: a salon opens the app
// with no style chosen, no lock yet, and nothing captured.

// MARK: - Lock-on state (R-CALIB)

/// Calibration is a state indicator, never a screen. A customer sitting in a chair being
/// watched by a stylist will not sit through onboarding, so this is the entire
/// calibration UI: one line that changes.
enum LockState {
    case searching, locked, lost

    var caption: String {
        switch self {
        case .searching: return "Finding your face"
        case .locked:    return "Holding"
        case .lost:      return "Lost you, move back into frame"
        }
    }
    var tint: Color {
        switch self {
        case .searching: return Tokens.Colour.inkMuted
        case .locked:    return Tokens.Colour.brass
        case .lost:      return Tokens.Colour.clay
        }
    }
}

struct LockIndicator: View {
    let state: LockState
    @State private var pulse = false

    var body: some View {
        HStack(spacing: Tokens.Space.snug) {
            Circle()
                .fill(state.tint)
                .frame(width: 7, height: 7)
                .opacity(state == .searching && pulse ? 0.25 : 1)
                .animation(
                    state == .searching
                        ? Tokens.Motion.settle.repeatForever(autoreverses: true)
                        : Tokens.Motion.calm,
                    value: pulse
                )
            Tokens.Typography.label(state.caption).foregroundStyle(Tokens.Colour.ink)
        }
        .padding(.horizontal, Tokens.Space.base)
        .padding(.vertical, Tokens.Space.snug)
        .background(Tokens.Colour.scrim, in: Capsule())
        .onAppear { pulse = true }
    }
}

// MARK: - Honesty disclosure (R-HONEST)

/// Live mode adds hair and cannot remove it. The whole category hides this. We print it.
///
/// Deliberately set at label size rather than caption size. Shrinking it into a footnote
/// would be the design decision that quietly undoes the requirement, so the type scale is
/// carrying the product position here, not just describing it.
struct HonestyNote: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.snug) {
            Text("+")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Tokens.Colour.brass)
            Tokens.Typography.label("This adds length and volume over your own hair. It cannot show it shorter.")
                .foregroundStyle(Tokens.Colour.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colour.scrim, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.medium)
                .stroke(Tokens.Colour.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Style carousel

struct HairStyle: Identifiable {
    let id: String
    let name: String
    /// Nil when the generated thumbnail has not been produced yet, which is the normal
    /// state while the ADR-004 pipeline is building the catalogue.
    let swatch: Color?
    let addsOnly: Bool
}

/// Circular thumbnail, the convergent pattern across every live-AR try-on examined.
/// Shows the style, never a score, never a fit (R-NOJUDGE).
struct StyleChip: View {
    let style: HairStyle
    let selected: Bool

    var body: some View {
        VStack(spacing: Tokens.Space.tight) {
            ZStack {
                Circle().fill(style.swatch ?? Tokens.Colour.surface)
                if style.swatch == nil {
                    // Sparse case: no thumbnail yet. Says so rather than showing a
                    // spinner forever or an empty hole.
                    Tokens.Typography.micro("—").foregroundStyle(Tokens.Colour.inkFaint)
                }
            }
            .frame(width: 62, height: 62)
            .overlay(
                Circle().stroke(
                    selected ? Tokens.Colour.brass : Tokens.Colour.hairline,
                    lineWidth: selected ? 2 : 1
                )
            )

            Tokens.Typography.micro(style.name)
                .foregroundStyle(selected ? Tokens.Colour.ink : Tokens.Colour.inkMuted)
                .lineLimit(1)
        }
        .frame(width: 76)
        .animation(Tokens.Motion.calm, value: selected)
    }
}

struct StyleCarousel: View {
    let styles: [HairStyle]
    let selectedID: String?

    var body: some View {
        if styles.isEmpty {
            // Sparse case. A carousel with nothing in it is a real state during a build
            // and it must read as a sentence, not as a broken row.
            Tokens.Typography.label("No styles loaded")
                .foregroundStyle(Tokens.Colour.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Tokens.Space.loose)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Space.snug) {
                    ForEach(styles) { s in
                        StyleChip(style: s, selected: s.id == selectedID)
                    }
                }
            }
        }
    }
}

// MARK: - Category tabs

struct CategoryTabs: View {
    let categories: [String]
    let selected: String?

    var body: some View {
        HStack(spacing: Tokens.Space.loose) {
            ForEach(categories, id: \.self) { c in
                VStack(spacing: Tokens.Space.tight) {
                    Tokens.Typography.micro(c)
                        .foregroundStyle(c == selected ? Tokens.Colour.ink : Tokens.Colour.inkFaint)
                    Rectangle()
                        .fill(c == selected ? Tokens.Colour.brass : .clear)
                        .frame(height: 1.5)
                }
                .fixedSize()
            }
            Spacer(minLength: 0)
        }
        .animation(Tokens.Motion.calm, value: selected)
    }
}

// MARK: - Capture

/// Tap for a still, press and hold to freeze and remove. One control, two modes, which is
/// the AR Quick Look convention rather than an invention.
struct CaptureButton: View {
    let holding: Bool

    var body: some View {
        ZStack {
            Circle().stroke(Tokens.Colour.ink.opacity(0.9), lineWidth: 2.5).frame(width: 68, height: 68)
            Circle()
                .fill(holding ? Tokens.Colour.brass : Tokens.Colour.ink)
                .frame(width: holding ? 30 : 56, height: holding ? 30 : 56)
                .animation(Tokens.Motion.calm, value: holding)
        }
    }
}

// MARK: - Freeze result (ADR-001)

/// Freeze mode is the only place a short cut can be shown, and it is a simulation of a
/// single frame rather than a live view. Labelled as such, permanently and not on a
/// dismissible toast, because the difference matters to somebody about to commit to a cut.
struct FreezeResultCard: View {
    let styleName: String?
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.snug) {
            HStack {
                Tokens.Typography.micro("Simulated").foregroundStyle(Tokens.Colour.brass)
                Spacer()
                if let p = progress {
                    Tokens.Typography.micro("\(Int(p * 100))%").foregroundStyle(Tokens.Colour.inkMuted)
                }
            }

            if let styleName {
                Tokens.Typography.title(styleName).foregroundStyle(Tokens.Colour.ink)
                Tokens.Typography.body("Your own hair removed for this one frame. Turning your head returns to the live view.")
                    .foregroundStyle(Tokens.Colour.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Sparse case: mid-computation, before there is anything to name.
                Tokens.Typography.title("Working").foregroundStyle(Tokens.Colour.ink)
            }

            if let p = progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Tokens.Colour.surface)
                        Capsule().fill(Tokens.Colour.brass).frame(width: geo.size.width * p)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(Tokens.Space.base)
        .background(Tokens.Colour.scrim, in: RoundedRectangle(cornerRadius: Tokens.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.large)
                .stroke(Tokens.Colour.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Real versus style (the differentiator nobody ships)

/// A live side-by-side of the customer's real hair against the style. No product examined
/// offers this. In a salon it is the actual conversation: this is you now, this is you
/// after. It shows two states of one person and ranks neither (R-NOJUDGE).
struct SplitCompare: View {
    let styleName: String?
    var body: some View {
        HStack(spacing: Tokens.Space.hair) {
            pane(label: "Now", tint: Tokens.Colour.surface, caption: "Your hair")
            pane(
                label: "After",
                tint: Tokens.Colour.surfaceRaised,
                caption: styleName ?? "Nothing selected"   // sparse case
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    }

    private func pane(label: String, tint: Color, caption: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.tight) {
            Tokens.Typography.micro(label).foregroundStyle(Tokens.Colour.brass)
            Tokens.Typography.label(caption)
                .foregroundStyle(Tokens.Colour.ink)
                .lineLimit(1)
        }
        .padding(Tokens.Space.base)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .bottomLeading)
        .background(tint)
    }
}

// MARK: - End session (R-RESET, ADR-005)

/// Not a navigation transition. This destroys the session, and on a shared salon device
/// used by strangers back to back it is a biometric control rather than a convenience.
/// Coloured and sized like it means it, because the stylist is mid-conversation and will
/// otherwise walk past it.
struct EndSessionButton: View {
    var body: some View {
        HStack(spacing: Tokens.Space.snug) {
            Image(systemName: "xmark.circle.fill").font(.system(size: 17))
            Tokens.Typography.label("End and erase")
        }
        .foregroundStyle(Tokens.Colour.ink)
        .padding(.horizontal, Tokens.Space.loose)
        .padding(.vertical, Tokens.Space.snug + 2)
        .background(Tokens.Colour.clay, in: Capsule())
    }
}

/// Fires before the idle timeout tears the session down anyway. The stylist forgetting is
/// the expected case, not the exception, so the automatic path is the real control and
/// this is only courtesy.
struct IdleWarning: View {
    let seconds: Int
    var body: some View {
        HStack(spacing: Tokens.Space.snug) {
            Circle().fill(Tokens.Colour.clay).frame(width: 7, height: 7)
            Tokens.Typography.label("Erasing this session in \(seconds)s")
                .foregroundStyle(Tokens.Colour.ink)
        }
        .padding(.horizontal, Tokens.Space.base)
        .padding(.vertical, Tokens.Space.snug)
        .background(Tokens.Colour.scrim, in: Capsule())
        .overlay(Capsule().stroke(Tokens.Colour.clay.opacity(0.6), lineWidth: 1))
    }
}

// MARK: - Unsupported device (R-DEGRADE)

/// Never a crash, never a black camera. The stylist must be able to read this and know it
/// is the iPad and not them.
struct UnsupportedDeviceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.base) {
            Tokens.Typography.title("This iPad cannot run the try-on")
                .foregroundStyle(Tokens.Colour.ink)
            Tokens.Typography.body("It needs an iPad from 2020 or later, or an iPhone XS or later. Nothing is wrong with your setup.")
                .foregroundStyle(Tokens.Colour.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.loose)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colour.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.large))
    }
}
