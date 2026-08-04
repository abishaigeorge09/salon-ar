import SwiftUI

/// Pre-Gate-2. The only thing this app contains is the kitchen sink, which exists so a
/// direction can be rejected for the price of one page rather than after screens are
/// built. There is deliberately no camera, no ARKit session, and no product code yet.
@main
struct SalonARApp: App {
    var body: some Scene {
        WindowGroup { KitchenSinkView() }
    }
}
