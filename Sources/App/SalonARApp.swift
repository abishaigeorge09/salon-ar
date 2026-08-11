import SwiftUI

/// SPIKE BUILD. Live camera, face tracking, one crude hair mesh.
///
/// This is not the product. There is no occlusion (hair clips through ears), no hairstyle
/// catalogue, and no freeze mode, so a customer asking to see a bob cannot be served.
/// Its only job is to answer whether a thing anchored to a face holds when the head turns
/// and whether that feels right in the hand.
///
/// The approved design direction lives in KitchenSinkView, reachable by long-pressing the
/// caption at the bottom of the spike screen.
@main
struct SalonARApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @State private var showingDirection = false

    var body: some View {
        SpikeScreen()
            .onLongPressGesture(minimumDuration: 0.6) { showingDirection = true }
            .sheet(isPresented: $showingDirection) { KitchenSinkView() }
    }
}
