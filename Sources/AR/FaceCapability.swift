import ARKit

/// ADR-002. The device gate, and the single source of truth for the device matrix.
///
/// The brief assumed face tracking needs a TrueDepth camera. It has not since iOS 14:
/// `ARFaceTrackingConfiguration` runs on any device with a front camera and an A12 Bionic
/// or later, TrueDepth or not. The requirement moved from the depth sensor to the Neural
/// Engine, which is why most iPads a salon already owns will work.
///
/// Gated at runtime rather than by a device-model allowlist. An allowlist rots on every
/// hardware release and silently excludes devices that would have worked; the capability
/// check is what Apple actually guarantees.
enum FaceCapability {

    /// Injectable so the unsupported path can be tested without owning an old iPad, which
    /// matters because we do not own one at all (docs/DEBT.md D-001).
    ///
    /// Main-actor isolated rather than `nonisolated(unsafe)`: it is only ever read from a
    /// view and only ever written from a test, both of which are already on the main
    /// actor, so the isolation costs nothing and Swift 6 gets a real guarantee instead of
    /// a suppressed warning.
    @MainActor static var overrideSupported: Bool?

    @MainActor static var isSupported: Bool {
        overrideSupported ?? ARFaceTrackingConfiguration.isSupported
    }

    /// Whether the device also has a true depth map. Preferred, never required — it
    /// refines the head-proxy fit in ADR-003 and changes nothing else.
    static var hasDepth: Bool {
        ARFaceTrackingConfiguration.supportedVideoFormats.isEmpty == false
            && ARFaceTrackingConfiguration.isSupported
    }

    /// The matrix as stated in ADR-002, kept beside the runtime gate so the document and
    /// the binary cannot drift apart. Written for a stylist reading a screen, not for a
    /// spec sheet.
    static let requirementSentence =
        "It needs an iPad from 2020 or later, or an iPhone XS or later. Nothing is wrong with your setup."
}
