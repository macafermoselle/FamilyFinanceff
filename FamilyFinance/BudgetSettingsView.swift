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
    @Query(sort: \ExpenseCategory.name) var myCategories: [ExpenseCategory]
    
    // Lo hacemos opcional para manejar la selección
    @State private var selectedCategory: String?
    @State private var limit = 0.0
    
    var availableCategories: [String] {
        let usedCategories = existingBudgets.map { $0.category }
        let allCategoryNames = myCategories.map { $0.name }
        return allCategoryNames.filter { !usedCategories.contains($0) }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if availableCategories.isEmpty {
                    ContentUnavailableView("Todo listo", systemImage: "checkmark.circle", description: Text("Ya configuraste todos los presupuestos posibles."))
                } else {
                    // 1. SECCIÓN DE CATEGORÍAS (TIPO CARRUSEL) 🎠
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableCategories, id: \.self) { catName in
                                    // Buscamos el ícono
                                    let icon = myCategories.first(where: { $0.name == catName })?.icon ?? "tag.fill"
                                    let isSelected = selectedCategory == catName
                                    
                                    // EL BOTÓN GRANDE ("BOX")
                                    Button {
                                        withAnimation {
                                            selectedCategory = catName
                                        }
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: icon)
                                                .font(.title2)
                                                .foregroundStyle(isSelected ? .white : .blue)
                                            
                                            Text(catName)
                                                .font(.caption)
                                                .fontWeight(isSelected ? .bold : .regular)
                                                .foregroundStyle(isSelected ? .white : .primary)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 100, height: 80) // <--- ACÁ CONTROLÁS EL TAMAÑO DEL BOX
                                        .background(isSelected ? Color.blue : Color(uiColor: .systemGray6))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.blue, lineWidth: isSelected ? 0 : 1)
                                                .opacity(isSelected ? 0 : 0.3)
                                        )
                                    }
                                    .buttonStyle(.plain) // Para que no parpadee toda la lista al tocar
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        }
                    } header: {
                        Text("Elegí una categoría")
                    }
                    .listRowInsets(EdgeInsets()) // Esto hace que ocupe todo el ancho de la pantalla (sin bordes blancos)
                    .listRowBackground(Color.clear) // Fondo transparente para que flote
                    
                    // 2. EL MONTO
                    Section("Límite Mensual") {
                        HStack {
                            Text("$").bold().foregroundStyle(.secondary)
                            TextField("0", value: $limit, format: .currency(code: "ARS"))
                                .keyboardType(.decimalPad)
                                .font(.title3)
                        }
                    }
                }
            }
            .navigationTitle("Nuevo Límite")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if let category = selectedCategory {
                            let newBudget = CategoryBudget(category: category, limit: limit)
                            modelContext.insert(newBudget)
                            dismiss()
                        }
                    }
                    .disabled(limit == 0 || selectedCategory == nil)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onAppear {
                // Selecciona el primero automáticamente para ahorrarte un click
                if selectedCategory == nil, let first = availableCategories.first {
                    selectedCategory = first
                }
            }
        }
    }
}
