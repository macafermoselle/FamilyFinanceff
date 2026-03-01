import SwiftUI
import SwiftData
import CloudKit
import UIKit // Necesario para UICloudSharingController

struct FamilySettingsView: View {
    @EnvironmentObject var settings: FamilySettings
    @Query var expenses: [Expense]
    
    @StateObject private var shareManager = CloudSharingManager.shared
    @State private var showShareSheet = false
    @State private var isProcessing = false
    
    let availableColors = ["purple", "blue", "green", "orange", "red", "pink", "black"]

    var body: some View {
        Form {
            Section("Identidad") {
                TextField("Tu Nombre", text: $settings.myName)
                TextField("Nombre de tu Pareja", text: $settings.partnerName)
                
                Picker("Tu Color", selection: $settings.myColorName) {
                    ForEach(availableColors, id: \.self) { name in
                        Label(name.capitalized, systemImage: "circle.fill")
                            .foregroundStyle(settings.colorFromString(name))
                            .tag(name)
                    }
                }
            }
            
            // 👇 NUEVA SECCIÓN: ESTADO DE FAMILIA VISUAL
            Section("Estado de la Familia") {
                if shareManager.isSharing, let share = shareManager.share {
                    // 1. TU ESTADO (Propietario)
                    HStack {
                        Image(systemName: "crown.fill").foregroundStyle(.yellow)
                        VStack(alignment: .leading) {
                            Text(settings.myName + " (Yo)")
                                .font(.headline)
                            Text("Organizador")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Activo").font(.caption).foregroundStyle(.green)
                    }
                    
                    // 2. ESTADO DE FACUNDO (Participante)
                    HStack {
                        Image(systemName: "person.2.fill").foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(settings.partnerName) // Usamos el nombre que vos pusiste
                                .font(.headline)
                            
                            // CORRECCIÓN 1: Quitamos el 'if let' porque participants no es opcional
                            let participants = share.participants
                            if let partner = participants.first(where: { $0 != share.owner }) {
                                Text(statusText(for: partner.acceptanceStatus))
                                    .font(.caption)
                                    .foregroundStyle(statusColor(for: partner.acceptanceStatus))
                            } else {
                                Text("Esperando invitación...")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                    }
                } else {
                    Text("No hay familia configurada aún.")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section(header: Text("Gestión iCloud"), footer: footerText) {
                if isProcessing {
                    HStack { Text("Procesando..."); Spacer(); ProgressView() }
                } else {
                    Button {
                        handleShareButton()
                    } label: {
                        Label(
                            shareManager.isSharing ? "Ver Opciones de iCloud (Apple)" : "Invitar a \(settings.partnerName)",
                            systemImage: "link"
                        )
                    }
                }
            }
            
            Section("Diagnóstico Técnico") {
                HStack {
                    Text("Estado Share:")
                    Spacer()
                    Text(shareManager.isSharing ? "ACTIVO ✅" : "INACTIVO ❌")
                        .foregroundStyle(shareManager.isSharing ? .green : .secondary)
                        .bold()
                }
                Text("Total Gastos Locales: \(expenses.count)")
            }
        }
        .navigationTitle("Ajustes")
        .sheet(isPresented: $showShareSheet) {
            ShareControllerWrapper(manager: shareManager)
        }
    }
    
    // CORRECCIÓN 2: Actualizamos el nombre del tipo de dato
    func statusText(for status: CKShare.ParticipantAcceptanceStatus) -> String {
        switch status {
        case .accepted: return "Conectado ✅"
        case .pending: return "Invitación enviada (Pendiente) ⏳"
        case .removed: return "Eliminado ❌"
        case .unknown: return "Desconocido ❓"
        @unknown default: return "Estado desconocido"
        }
    }
    
    // CORRECCIÓN 3: Actualizamos el nombre aquí también
    func statusColor(for status: CKShare.ParticipantAcceptanceStatus) -> Color {
        switch status {
        case .accepted: return .green
        case .pending: return .orange
        case .removed: return .red
        default: return .gray
        }
    }
    
    var footerText: some View {
        Text(shareManager.isSharing
             ? "Podés usar el menú de Apple para reenviar el link o dejar de compartir."
             : "Tocá 'Invitar' para crear un link de iCloud y mandárselo a \(settings.partnerName).")
    }
    
    func handleShareButton() {
        if shareManager.isSharing {
            showShareSheet = true
        } else {
            isProcessing = true
            shareManager.createShare { share, error in
                isProcessing = false
                if share != nil {
                    showShareSheet = true
                }
            }
        }
    }
}
