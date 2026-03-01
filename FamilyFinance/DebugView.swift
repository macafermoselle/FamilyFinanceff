import SwiftUI
import SwiftData

struct DebugView: View {
    @ObservedObject var manager = CloudSharingManager.shared
    @State private var manualLink: String = ""
    @State private var statusMessage: String = "Listo"
    @State private var isProcessing: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("Estado CloudKit") {
                    HStack {
                        Circle()
                            .fill(manager.isSharing ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text(manager.connectionStatus)
                    }
                }
                
                Section(header: Text("Unirse Manualmente (Si el link no abre)"), footer: Text("Facundo: Pega aquí el link que te mandó Maca.")) {
                    TextField("Pegar link de iCloud aquí...", text: $manualLink)
                        .font(.caption)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    Button {
                        processManualLink()
                    } label: {
                        if isProcessing {
                            ProgressView()
                        } else {
                            Text("Unirse a la Billetera")
                        }
                    }
                    .disabled(manualLink.isEmpty || isProcessing)
                }
                
                if !statusMessage.isEmpty {
                    Section("Resultado") {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(statusMessage.contains("Error") ? .red : .blue)
                    }
                }
            }
            .navigationTitle("Sincronización")
        }
    }
    
    func processManualLink() {
        isProcessing = true
        statusMessage = "Conectando con Apple..."
        
        manager.acceptShare(from: manualLink) { result in
            isProcessing = false
            statusMessage = result
            if result.contains("Éxito") {
                manualLink = ""
            }
        }
    }
}
