import SwiftUI
import UIKit

@main
struct UntisCloneApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                ContentView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
}
