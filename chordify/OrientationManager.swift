import UIKit

enum OrientationManager {
    static func enterLandscape() {
        AppDelegate.orientationLock = .landscapeRight
        requestGeometry(.landscapeRight)
    }

    static func exitLandscape() {
        AppDelegate.orientationLock = .portrait
        requestGeometry(.portrait)
    }

    private static func requestGeometry(_ mask: UIInterfaceOrientationMask) {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
    }
}
