import SwiftUI
import SwiftData
import LocalAuthentication

@main
struct FamilyFinanceApp: App {
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Expense.self,
            CreditCard.self,
            FixedCost.self,
            Income.self,
            FixedIncome.self,
            CategoryBudget.self,
            SavingGoal.self,
            ExpenseCategory.self // <--- 1. AGREGAR ESTO
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var isUnlocked = false
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isUnlocked {
                    ContentView()
                        // 2. INYECTAR DATOS POR DEFECTO AL INICIAR
                        .onAppear {
                            seedCategories(context: sharedModelContainer.mainContext)
                        }
                } else {
                    LockScreenView(isUnlocked: $isUnlocked)
                }
            }
            .modelContainer(sharedModelContainer)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background || newPhase == .inactive {
                    isUnlocked = false
                }
            }
        }
    }
    
    // 3. FUNCIÓN PARA CREAR LAS CATEGORÍAS BÁSICAS
    func seedCategories(context: ModelContext) {
        do {
            // Verificamos si ya existen categorías
            let descriptor = FetchDescriptor<ExpenseCategory>()
            let count = try context.fetchCount(descriptor)
            
            if count == 0 {
                // Si está vacío, creamos las de siempre
                let defaults = [
                    ExpenseCategory(name: "Supermercado", icon: "cart.fill"),
                    ExpenseCategory(name: "Comida", icon: "fork.knife"),
                    ExpenseCategory(name: "Transporte", icon: "car.fill"),
                    ExpenseCategory(name: "Servicios", icon: "bolt.fill"),
                    ExpenseCategory(name: "Farmacia", icon: "cross.case.fill"),
                    ExpenseCategory(name: "Ropa", icon: "tshirt.fill"),
                    ExpenseCategory(name: "Ocio", icon: "popcorn.fill"),
                    ExpenseCategory(name: "Varios", icon: "bag.fill")
                ]
                
                for cat in defaults {
                    context.insert(cat)
                }
                print("Categorías por defecto cargadas.")
            }
        } catch {
            print("Error cargando categorías: \(error)")
        }
    }
}

// VISTA DE BLOQUEO
struct LockScreenView: View {
    @Binding var isUnlocked: Bool
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
                .padding()
            
            Text("Family Finance")
                .font(.largeTitle).bold()
            
            Text("App protegida")
                .font(.caption).foregroundStyle(.secondary)
            
            if !errorMessage.isEmpty {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            
            Button {
                authenticate()
            } label: {
                Label("Desbloquear con FaceID", systemImage: "faceid")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: 250)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .onAppear {
            authenticate()
        }
    }
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Desbloquea para ver tus finanzas."

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        withAnimation {
                            isUnlocked = true
                        }
                    } else {
                        errorMessage = "No se pudo verificar tu identidad."
                    }
                }
            }
        } else {
            // Si no tiene FaceID configurado, entra directo
            isUnlocked = true
        }
    }
}
