import LocalAuthentication

class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false

    func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Password"
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Mactokio") { success, _ in
                DispatchQueue.main.async {
                    self.isAuthenticated = success
                    completion(success)
                }
            }
        } else {
            completion(false)
        }
    }

}
