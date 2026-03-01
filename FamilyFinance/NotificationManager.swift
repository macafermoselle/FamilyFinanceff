import UserNotifications
import SwiftUI

class NotificationManager {
    static let shared = NotificationManager()
    
    // 1. Pedir Permiso
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Permiso concedido")
            } else if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    // 2. Agendar Notificación Diaria
    func scheduleDailyReminder(at hour: Int, minute: Int) {
        // Primero borramos las anteriores para no duplicar
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = "Family Finance 💸"
        content.body = "¿Hiciste algún gasto hoy? No te olvides de anotarlo."
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
        print("Recordatorio programado para las \(hour):\(minute)")
    }
    
    // 3. Cancelar Notificaciones
    func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
