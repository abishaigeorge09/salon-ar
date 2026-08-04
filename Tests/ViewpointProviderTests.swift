import XCTest
import simd
@testable import salon_ar

/// ADR-006's Confirmation. This is the actual test of "the mirror version is not
/// foreclosed": if an off-axis viewpoint re-projects correctly today, with no change to
/// tracking or assets, then the mirror is a port rather than a rewrite.
///
/// Runs anywhere. It is pure linear algebra and needs no device, which is why it can hold
/// the seam from the first commit rather than waiting for hardware.
final class ViewpointProviderTests: XCTestCase {

    private func translation(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3 = [x, y, z, 1]
        return m
    }

    func testHandheldViewpointIsTheCamera() {
        let camera = translation(0.1, 0.2, -0.3)
        let result = CameraViewpoint().viewpoint(forCamera: camera)
        XCTAssertEqual(result, camera, "Handheld must pass the camera through untouched")
    }

    func testOffAxisViewpointReprojects() {
        // A mirror mounted half a metre to the left of the viewer's eyeline.
        let offset = translation(-0.5, 0, 0)
        let camera = translation(0.1, 0.2, -0.3)

        let result = OffAxisViewpoint(cameraToViewer: offset).viewpoint(forCamera: camera)

        // It must actually move. An off-axis provider that returns the camera unchanged
        // would pass a naive test while proving the seam does nothing.
        XCTAssertNotEqual(result, camera, "Off-axis must not be a no-op")
        XCTAssertEqual(result.columns.3.x, -0.4, accuracy: 1e-5)
        XCTAssertEqual(result.columns.3.y,  0.2, accuracy: 1e-5)
        XCTAssertEqual(result.columns.3.z, -0.3, accuracy: 1e-5)
    }

    func testOffAxisIdentityDegradesToHandheld() {
        let camera = translation(1, 2, 3)
        let result = OffAxisViewpoint(cameraToViewer: matrix_identity_float4x4)
            .viewpoint(forCamera: camera)
        XCTAssertEqual(result, camera)
    }
}
