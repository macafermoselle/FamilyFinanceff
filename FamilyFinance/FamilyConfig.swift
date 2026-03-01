import SwiftUI
import Combine

class FamilySettings: ObservableObject {
    @Published var myName: String {
        didSet { UserDefaults.standard.set(myName, forKey: "userName") }
    }
    
    @Published var partnerName: String {
        didSet { UserDefaults.standard.set(partnerName, forKey: "partnerName") }
    }
    
    @Published var myColorName: String {
        didSet { UserDefaults.standard.set(myColorName, forKey: "userColor") }
    }
    
    @Published var partnerColor: String {
        didSet { UserDefaults.standard.set(partnerColor, forKey: "partnerColor") }
    }
    
    // 👇 NUEVO: Identificador único del dispositivo (Huella digital)
    let deviceID: String
    
    init() {
        self.myName = UserDefaults.standard.string(forKey: "userName") ?? "Yo"
        self.partnerName = UserDefaults.standard.string(forKey: "partnerName") ?? "Pareja"
        self.myColorName = UserDefaults.standard.string(forKey: "userColor") ?? "purple"
        self.partnerColor = UserDefaults.standard.string(forKey: "partnerColor") ?? "blue"
        
        // Si no existe un ID, creamos uno y lo guardamos
        if let storedID = UserDefaults.standard.string(forKey: "deviceID") {
            self.deviceID = storedID
        } else {
            let newID = UUID().uuidString
            self.deviceID = newID
            UserDefaults.standard.set(newID, forKey: "deviceID")
        }
    }
    
    // Devuelve el color de la persona (Mío o Suyo)
    func getColor(forUser isMe: Bool) -> Color {
        let colorName = isMe ? myColorName : partnerColor
        return colorFromString(colorName)
    }
    
    func colorFromString(_ name: String) -> Color {
        switch name {
            case "purple": return .purple
            case "blue": return .blue
            case "green": return .green
            case "orange": return .orange
            case "red": return .red
            case "pink": return .pink
            case "black": return .black
            default: return .gray
        }
    }
}
