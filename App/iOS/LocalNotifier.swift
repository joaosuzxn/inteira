import UserNotifications
import ArCore

/// Avisa o dono do que a automação fez, com notificação local entregue na hora.
struct LocalNotifier: AutomationNotifying {
    func notify(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // Sem gatilho: o iOS entrega imediatamente.
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Pede permissão para mostrar avisos (chamado ao ligar o automático).
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
}
