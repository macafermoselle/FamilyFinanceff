import SwiftUI
import SwiftData

struct BudgetSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var budgets: [CategoryBudget]
    
    @State private var showingAdd = false
    
    var body: some View {
        List {
            if budgets.isEmpty {
                ContentUnavailableView("Sin Presupuestos", systemImage: "chart.bar.doc.horizontal", description: Text("Define límites para tus gastos."))
            }
            
            ForEach(budgets) { budget in
                HStack {
                    Text(budget.category)
                        .font(.headline)
                    Spacer()
                    Text(budget.limit.formatted(.currency(code: "ARS")))
                        .bold()
                        .foregroundStyle(.blue)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        modelContext.delete(budget)
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Presupuestos")
        .toolbar {
            Button(action: { showingAdd = true }) {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddBudgetView()
        }
    }
}

struct AddBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query var existingBudgets: [CategoryBudget]
    
    @State private var selectedCategory = "Supermercado"
    @State private var limit = 0.0
    
    // Las mismas categorías que usas en los gastos
    let categories = ["Supermercado", "Comida", "Transporte", "Servicios", "Farmacia", "Ropa", "Ocio", "Varios"]
    
    // Filtramos las categorías que YA tienen presupuesto para no duplicar
    var availableCategories: [String] {
        let usedCategories = existingBudgets.map { $0.category }
        return categories.filter { !usedCategories.contains($0) }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if availableCategories.isEmpty {
                    Text("¡Ya has configurado todas las categorías!")
                } else {
                    Picker("Categoría", selection: $selectedCategory) {
                        ForEach(availableCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    
                    TextField("Límite Mensual", value: $limit, format: .currency(code: "ARS"))
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Nuevo Límite")
            .toolbar {
                Button("Guardar") {
                    let newBudget = CategoryBudget(category: selectedCategory, limit: limit)
                    modelContext.insert(newBudget)
                    dismiss()
                }
                .disabled(limit == 0 || availableCategories.isEmpty)
            }
            .onAppear {
                if let first = availableCategories.first {
                    selectedCategory = first
                }
            }
        }
    }
}
