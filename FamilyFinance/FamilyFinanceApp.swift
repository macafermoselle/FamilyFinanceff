import SwiftUI
import SwiftData
import CloudKit
import LocalAuthentication

@main
struct FamilyFinanceApp: App {
    // 1. Creamos la instancia única aquí (IMPORTANTE)
    @StateObject private var settings = FamilySettings()
    
    static var sharedModelContainer: ModelContainer = {
        // ... (Tu código de contenedor que ya está perfecto) ...
        let schema = Schema([
            FamilyLedger.self, Expense.self, Income.self, FixedCost.self,
            CreditCard.self, FixedIncome.self, CategoryBudget.self,
            SavingGoal.self, ExpenseCategory.self, Vacation.self,
            SavingMovement.self // Asegurate que esté acá
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            if let path = urls.first {
                let contents = try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
                contents?.forEach { try? FileManager.default.removeItem(at: $0) }
            }
            return try! ModelContainer(for: schema, configurations: [modelConfiguration])
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings) // 👈 ESTO ES LO QUE REPARA EL ERROR
                .modelContainer(Self.sharedModelContainer)
        }
    }
}
