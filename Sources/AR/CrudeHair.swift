import RealityKit
import simd

/// SPIKE-QUALITY. This is deliberately crude and is not the asset pipeline.
///
/// ADR-004 says hairstyles are parameterised hair cards over a shared skull cap, generated
/// by a script from one config row each. None of that exists yet. This is three scaled
/// spheres in the rough shape of a head of hair, and its only job is to answer one
/// question: does a thing anchored to your face hold when you turn your head, and does it
/// feel right in the hand.
///
/// It WILL clip through your ears and cut across your forehead. That is not a bug in this
/// file, it is the absence of ADR-003, which is Phase 1's actual work. Naming it here so
/// nobody files it as a defect or, worse, tries to fix it in the spike.
enum CrudeHair {

    /// Rough head measurements in metres, taken from ARKit's face anchor origin, which
    /// sits behind the nose rather than at the centre of the skull.
    private enum Head {
        static let up: Float = 0.055        // face origin to roughly the crown
        static let back: Float = -0.02      // hair sits behind the face plane
        static let width: Float = 0.095
        static let depth: Float = 0.105
        static let height: Float = 0.085
    }

    /// Main-actor isolated: RealityKit entities and materials are not Sendable and are
    /// only ever built from the view layer, so the isolation is the truth rather than a
    /// workaround.
    ///
    /// A dark, matte, deliberately unconvincing mass. Matte because a specular highlight
    /// on a sphere reads as a bowling ball, and the point is to judge tracking, not looks.
    @MainActor static func entity() -> ModelEntity {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(red: 0.20, green: 0.15, blue: 0.12, alpha: 1))
        material.roughness = .init(floatLiteral: 0.95)
        material.metallic = .init(floatLiteral: 0.0)

        let root = ModelEntity()

        // Crown: the main mass.
        let crown = ModelEntity(mesh: .generateSphere(radius: 0.5), materials: [material])
        crown.scale = [Head.width * 2, Head.height * 2, Head.depth * 2]
        crown.position = [0, Head.up, Head.back]
        root.addChild(crown)

        // Back mass, so a profile view is not an empty shell.
        let back = ModelEntity(mesh: .generateSphere(radius: 0.5), materials: [material])
        back.scale = [Head.width * 1.8, Head.height * 1.5, Head.depth * 1.4]
        back.position = [0, Head.up - 0.02, Head.back - 0.045]
        root.addChild(back)

        // A suggestion of a fringe, so there is something at the hairline to judge.
        let fringe = ModelEntity(mesh: .generateSphere(radius: 0.5), materials: [material])
        fringe.scale = [Head.width * 1.7, Head.height * 0.5, Head.depth * 0.5]
        fringe.position = [0, Head.up - 0.035, Head.back + 0.055]
        root.addChild(fringe)

        return root
    }
}
