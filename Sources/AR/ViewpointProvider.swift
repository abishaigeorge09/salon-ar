import simd

/// ADR-006. The seam that keeps the salon-mirror version a port rather than a rewrite.
///
/// In the handheld product the front camera sits roughly where the customer is looking, so
/// camera viewpoint and viewer viewpoint are interchangeable. A salon mirror breaks that:
/// the camera is mounted on the mirror, the viewer's eyes are somewhere else, and every
/// render that assumed they were the same is wrong by a parallax error.
///
/// The render path asks this for the viewpoint and never reads the AR camera transform
/// directly. In the handheld product the answer is "the camera", which is to say this does
/// nothing at all. That is the point: a few lines now, a rewrite later.
///
/// `scripts/verify-viewpoint-indirection.sh` fails the build on a direct camera read
/// anywhere else, because a seam that is merely documented erodes one commit at a time.
protocol ViewpointProvider {
    /// Given the AR camera's world transform, return the transform the scene should be
    /// rendered from.
    func viewpoint(forCamera cameraTransform: simd_float4x4) -> simd_float4x4
}

/// Handheld. The camera is the viewpoint, so this is deliberately the identity case.
struct CameraViewpoint: ViewpointProvider {
    func viewpoint(forCamera cameraTransform: simd_float4x4) -> simd_float4x4 {
        cameraTransform
    }
}

/// The mirror case, not shipped and not built for. It exists so the off-axis path can be
/// exercised by a test today: if an off-axis viewpoint renders correctly now, the mirror
/// version is a port. That test is ADR-006's Confirmation, and it is the only way to know
/// the seam still holds rather than to hope it does.
struct OffAxisViewpoint: ViewpointProvider {
    /// Rigid transform from camera space into the viewer's space.
    let cameraToViewer: simd_float4x4

    func viewpoint(forCamera cameraTransform: simd_float4x4) -> simd_float4x4 {
        cameraToViewer * cameraTransform
    }
}
