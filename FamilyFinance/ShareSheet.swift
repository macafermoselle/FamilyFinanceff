import SwiftUI
import UIKit
import CloudKit



// 2. WRAPPER CON REINTENTO ACTIVO DE URL 🛡️
// Este componente soluciona el problema de que el link no esté listo al abrir la hoja.
struct ShareControllerWrapper: View {
    @ObservedObject var manager: CloudSharingManager
    @State private var forceShow = false
    @State private var retryAttempt = 0
    @State private var isReady = false
    
    var body: some View {
        Group {
            // Caso A: Ya tenemos el link o el tiempo de espera se agotó (mostramos la hoja de Apple)
            if let share = manager.share, (share.url != nil || forceShow) {
                CloudSharingView(container: CKContainer(identifier: "iCloud.com.carya.familyfinances.2026"), share: share)
            }
            // Caso B: Tenemos el objeto pero estamos esperando que iCloud genere la URL pública
            else if let share = manager.share {
                VStack(spacing: 25) {
                    ProgressView()
                        .controlSize(.large)
                    
                    VStack(spacing: 10) {
                        Text("Sincronizando con iCloud...")
                            .font(.headline)
                        Text("Estamos obteniendo el enlace seguro de tu billetera familiar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if retryAttempt > 0 {
                            Text("Reintento de conexión \(retryAttempt + 1)...")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .padding(.top, 5)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                .presentationDetents([.medium])
                .task {
                    guard !isReady else { return }
                    await fetchURLActively(share: share)
                }
            }
            // Caso C: No hay objeto de compartir aún (estado inicial)
            else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Iniciando conexión familiar...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // Función para buscar activamente la URL en el servidor de Apple
    func fetchURLActively(share: CKShare) async {
        if share.url != nil {
            await MainActor.run { isReady = true }
            return
        }
        
        let container = CKContainer(identifier: "iCloud.com.carya.familyfinances.2026")
        
        // Intentamos 3 veces con una pausa entre medio
        for i in 1...3 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seg
            
            await MainActor.run { retryAttempt = i }
            print("🔄 Sincronizando metadatos (Intento \(i))...")
            
            do {
                // Forzamos un fetch del registro para ver si el servidor ya le asignó la URL
                let fetchedRecord = try await container.privateCloudDatabase.record(for: share.recordID)
                
                if let fetchedShare = fetchedRecord as? CKShare, let url = fetchedShare.url {
                    print("✅ Enlace confirmado: \(url)")
                    await MainActor.run {
                        manager.share = fetchedShare
                        isReady = true
                    }
                    return
                }
            } catch {
                print("⚠️ Esperando respuesta del servidor...")
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seg
        }
        
        // Si fallan los reintentos, abrimos la hoja de todas formas (Apple suele resolverlo al abrirse)
        print("⏰ Tiempo límite excedido. Abriendo hoja de compartir en modo manual.")
        await MainActor.run {
            forceShow = true
            isReady = true
        }
    }
}

