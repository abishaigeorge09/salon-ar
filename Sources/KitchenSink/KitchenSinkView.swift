import SwiftUI

/// The kitchen sink. Not a screen of the product: a page that renders every domain
/// component so a direction can be rejected for the price of one page rather than after
/// screens are built.
///
/// The rule this page exists to enforce: every component appears TWICE, once fully
/// populated and once nearly empty. Most real states in this product are sparse — no
/// style chosen, no lock yet, nothing captured — and a component that only holds together
/// in the full case is not finished.
///
/// Swatches read from Tokens at runtime. Nothing here copies a hex value, so the page
/// cannot drift from the tokens it is supposed to be showing.
struct KitchenSinkView: View {
    private let styles: [HairStyle] = [
        .init(id: "bob",      name: "Bob",       swatch: Color(red: 0.29, green: 0.24, blue: 0.21), addsOnly: false),
        .init(id: "layers",   name: "Layers",    swatch: Color(red: 0.36, green: 0.28, blue: 0.22), addsOnly: true),
        .init(id: "fringe",   name: "Fringe",    swatch: Color(red: 0.21, green: 0.18, blue: 0.17), addsOnly: true),
        .init(id: "volume",   name: "Volume",    swatch: Color(red: 0.44, green: 0.33, blue: 0.24), addsOnly: true),
        .init(id: "crop",     name: "Crop",      swatch: Color(red: 0.25, green: 0.21, blue: 0.19), addsOnly: false),
        .init(id: "pending",  name: "Building",  swatch: nil,                                        addsOnly: true)
    ]

    /// Scroll target, read from the launch environment. Lets a capture script screenshot
    /// any section without a UI automation dependency, which is also how the ADR-003
    /// render baselines will be captured later.
    private var anchor: String? { ProcessInfo.processInfo.environment["KS_ANCHOR"] }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.wide) {

                header

                section("Colour", note: "Read from Tokens at runtime. Brass means the system has hold of the face. Clay means this destroys something. No third meaning.") {
                    swatches
                }

                section("Type", note: "A step larger than a normal consumer app throughout, because the stylist reads this at arm's length across a chair.") {
                    VStack(alignment: .leading, spacing: Tokens.Space.snug) {
                        Tokens.Typography.display("Display 34").foregroundStyle(Tokens.Colour.ink)
                        Tokens.Typography.title("Title 24").foregroundStyle(Tokens.Colour.ink)
                        Tokens.Typography.body("Body 17, the size most copy is set at.").foregroundStyle(Tokens.Colour.ink)
                        Tokens.Typography.label("Label 15").foregroundStyle(Tokens.Colour.inkMuted)
                        Tokens.Typography.micro("Micro 12 tracked").foregroundStyle(Tokens.Colour.inkFaint)
                    }
                }

                section("Lock-on", note: "The entire calibration UI. A customer being watched by a stylist will not sit through onboarding.") {
                    pair(
                        populated: { LockIndicator(state: .locked) },
                        sparse:    { LockIndicator(state: .searching) },
                        sparseLabel: "searching",
                        extra:     { LockIndicator(state: .lost) },
                        extraLabel: "lost"
                    )
                }

                section("Honesty note", note: "R-HONEST. Set at label size, not caption size. Shrinking it to a footnote is how the requirement would quietly die.") {
                    HonestyNote()
                }

                section("Style carousel", note: "Circular thumbnails, the convergent pattern across every live-AR try-on examined. Shows the style, never a score.") {
                    pairStacked(
                        populated: { StyleCarousel(styles: styles, selectedID: "layers") },
                        sparse:    { StyleCarousel(styles: [], selectedID: nil) },
                        sparseLabel: "nothing loaded"
                    )
                }

                section("Categories") {
                    pairStacked(
                        populated: { CategoryTabs(categories: ["Length", "Volume", "Fringe", "Texture"], selected: "Volume") },
                        sparse:    { CategoryTabs(categories: ["Length"], selected: "Length") },
                        sparseLabel: "one category"
                    )
                }

                section("Capture", note: "Tap for a still, hold to freeze and remove. One control, two modes, per AR Quick Look.") {
                    HStack(spacing: Tokens.Space.wide) {
                        VStack(spacing: Tokens.Space.tight) {
                            CaptureButton(holding: false)
                            Tokens.Typography.micro("idle").foregroundStyle(Tokens.Colour.inkFaint)
                        }
                        VStack(spacing: Tokens.Space.tight) {
                            CaptureButton(holding: true)
                            Tokens.Typography.micro("holding").foregroundStyle(Tokens.Colour.inkFaint)
                        }
                    }
                }

                section("Freeze result", note: "ADR-001. The only place a shorter cut can be shown, and permanently labelled as a simulation of one frame.") {
                    pairStacked(
                        populated: { FreezeResultCard(styleName: "Bob, chin length", progress: nil) },
                        sparse:    { FreezeResultCard(styleName: nil, progress: 0.35) },
                        sparseLabel: "mid-computation, nothing to name yet"
                    )
                }

                section("Now / After", note: "The differentiator: no product examined offers a live side-by-side. In a salon this is the actual conversation.") {
                    pairStacked(
                        populated: { SplitCompare(styleName: "Layers") },
                        sparse:    { SplitCompare(styleName: nil) },
                        sparseLabel: "nothing selected"
                    )
                }

                section("Ending a session", note: "R-RESET. A biometric control on a shared device, not a navigation transition. The idle path is the real control; the button is courtesy.") {
                    VStack(alignment: .leading, spacing: Tokens.Space.base) {
                        EndSessionButton()
                        IdleWarning(seconds: 20)
                    }
                }

                section("Unsupported device", note: "R-DEGRADE. Never a crash, never a black camera.") {
                    UnsupportedDeviceView()
                }

                footer
            }
            .padding(Tokens.Space.loose)
        }
        .background(Tokens.Colour.base.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            guard let anchor else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.none) { proxy.scrollTo(anchor, anchor: .top) }
            }
        }
        }
    }

    // MARK: - Chrome of the page itself

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.snug) {
            Tokens.Typography.micro("Kitchen sink · direction").foregroundStyle(Tokens.Colour.brass)
            Tokens.Typography.display("Chair-side").foregroundStyle(Tokens.Colour.ink)
            Tokens.Typography.body("The chrome behaves like good salon lighting: present, warm, never the subject. The person in the chair is the subject, and every pixel we draw competes with their face.")
                .foregroundStyle(Tokens.Colour.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, Tokens.Space.snug)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.snug) {
            Tokens.Typography.micro("What this direction refuses").foregroundStyle(Tokens.Colour.brass)
            Tokens.Typography.body("No gradients, no glow, no pastel. That is the beauty-app register and it reads as a toy filter. A stylist charging for a consultation cannot be holding a toy, and every competitor examined sits in that register.")
                .foregroundStyle(Tokens.Colour.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Tokens.Space.base)
    }

    private var swatches: some View {
        // Reads from Tokens rather than repeating hex values, so this cannot drift.
        let entries: [(String, Color)] = [
            ("base", Tokens.Colour.base),
            ("surface", Tokens.Colour.surface),
            ("raised", Tokens.Colour.surfaceRaised),
            ("brass", Tokens.Colour.brass),
            ("clay", Tokens.Colour.clay),
            ("ink", Tokens.Colour.ink),
            ("muted", Tokens.Colour.inkMuted),
            ("faint", Tokens.Colour.inkFaint)
        ]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.snug), count: 4),
                         spacing: Tokens.Space.snug) {
            ForEach(entries, id: \.0) { name, colour in
                VStack(spacing: Tokens.Space.tight) {
                    RoundedRectangle(cornerRadius: Tokens.Radius.small)
                        .fill(colour)
                        .frame(height: 46)
                        .overlay(
                            RoundedRectangle(cornerRadius: Tokens.Radius.small)
                                .stroke(Tokens.Colour.hairline, lineWidth: 1)
                        )
                    Tokens.Typography.micro(name).foregroundStyle(Tokens.Colour.inkFaint)
                }
            }
        }
    }

    // MARK: - Layout helpers

    private func section<C: View>(_ title: String, note: String? = nil, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.base) {
            VStack(alignment: .leading, spacing: Tokens.Space.tight) {
                Tokens.Typography.micro(title).foregroundStyle(Tokens.Colour.brass)
                if let note {
                    Tokens.Typography.label(note)
                        .foregroundStyle(Tokens.Colour.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
            Rectangle().fill(Tokens.Colour.hairline).frame(height: 1)
        }
        .id(title)
    }

    /// Populated beside sparse, horizontally. Used where components are small enough to
    /// sit side by side.
    private func pair<A: View, B: View, C: View>(
        @ViewBuilder populated: () -> A,
        @ViewBuilder sparse: () -> B,
        sparseLabel: String,
        @ViewBuilder extra: () -> C,
        extraLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.snug) {
            labelled("populated") { populated() }
            labelled(sparseLabel) { sparse() }
            labelled(extraLabel) { extra() }
        }
    }

    /// Populated above sparse. Used where components are full width.
    private func pairStacked<A: View, B: View>(
        @ViewBuilder populated: () -> A,
        @ViewBuilder sparse: () -> B,
        sparseLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.base) {
            labelled("populated") { populated() }
            labelled(sparseLabel) { sparse() }
        }
    }

    private func labelled<C: View>(_ tag: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.tight) {
            Tokens.Typography.micro(tag).foregroundStyle(Tokens.Colour.inkFaint.opacity(0.7))
            content()
        }
    }
}

#Preview {
    KitchenSinkView()
}
