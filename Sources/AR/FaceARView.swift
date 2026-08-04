import SwiftUI
import RealityKit
import ARKit
import Combine

/// SPIKE. Live camera, face tracking, one crude hair mesh anchored to the head.
///
/// What this deliberately does NOT do, so it is not mistaken for progress on them:
///   - occlusion of any kind (ADR-003, Phase 1's real work). Hair clips through ears.
///   - hairstyles (ADR-004). There is one crude mass.
///   - freeze mode, removal, or anything a customer asking for a bob would need.
///
/// What it DOES respect, because these are cheap now and expensive to retrofit:
///   - the capability gate (ADR-002)
///   - ViewpointProvider indirection (ADR-006)
///   - nothing to disk, nothing to the network, session dies with the view (ADR-005)

/// Main-actor isolated so the ARSession delegate, which is called on a background queue,
/// must hop explicitly to touch it. Swift 6 enforces that rather than trusting a comment.
@MainActor final class FaceSessionState: ObservableObject {
    @Published var lock: LockState = .searching
}

struct FaceARView: UIViewRepresentable {
    @ObservedObject var state: FaceSessionState

    /// Handheld today. The mirror version swaps this and nothing else (ADR-006).
    let viewpoint: ViewpointProvider = CameraViewpoint()

    func makeCoordinator() -> Coordinator { Coordinator(state: state, viewpoint: viewpoint) }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.session.delegate = context.coordinator

        let anchor = AnchorEntity(.face)
        anchor.addChild(CrudeHair.entity())
        view.scene.addAnchor(anchor)
        context.coordinator.anchor = anchor

        let config = ARFaceTrackingConfiguration()
        config.maximumNumberOfTrackedFaces = 1     // one face, per the brief
        config.isLightEstimationEnabled = true     // groundwork for ADR-003's realism step
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        return view
    }

    func updateUIView(_ view: ARView, context: Context) {}

    /// ADR-005. Ending the view ends the session. There is exactly one teardown path,
    /// because a second path is one somebody forgets to call.
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        view.session.pause()
        view.scene.anchors.removeAll()
        coordinator.anchor = nil
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        private let state: FaceSessionState
        private let viewpoint: ViewpointProvider
        var anchor: AnchorEntity?

        init(state: FaceSessionState, viewpoint: ViewpointProvider) {
            self.state = state
            self.viewpoint = viewpoint
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // ADR-006: the render viewpoint comes from the provider, never read directly
            // off the frame. Today this is the identity case and costs a matrix copy.
            _ = viewpoint.viewpoint(forCamera: frame.camera.transform)
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
            let next: LockState = face.isTracked ? .locked : .lost
            Task { @MainActor [state] in
                if state.lock != next { state.lock = next }
            }
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            Task { @MainActor [state] in state.lock = .lost }
        }

        func sessionWasInterrupted(_ session: ARSession) {
            Task { @MainActor [state] in state.lock = .searching }
        }
    }
}

/// The spike screen. Full-bleed camera with the minimum chrome the IA calls for: lock
/// state, and the honesty note that says what this cannot show (R-HONEST).
struct SpikeScreen: View {
    @StateObject private var state = FaceSessionState()

    var body: some View {
        if !FaceCapability.isSupported {
            // R-DEGRADE: a written explanation, never a crash and never a black camera.
            ZStack {
                Tokens.Colour.base.ignoresSafeArea()
                UnsupportedDeviceView().padding(Tokens.Space.loose)
            }
        } else {
            ZStack(alignment: .top) {
                FaceARView(state: state).ignoresSafeArea()

                VStack(spacing: Tokens.Space.base) {
                    LockIndicator(state: state.lock)
                    Spacer()
                    HonestyNote()
                    Tokens.Typography.micro("spike build · crude mesh, no occlusion")
                        .foregroundStyle(Tokens.Colour.inkFaint)
                }
                .padding(Tokens.Space.loose)
            }
            .preferredColorScheme(.dark)
        }
    }
}
