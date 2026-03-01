import SwiftUI
import SwiftData

struct FixedCostsView: View {
    @Environment(\.modelContext) private var modelContext
    // Ordenamos por día de vencimiento
    @Query(sort: \FixedCost.dueDay) var fixedCosts: [FixedCost]
    
    @State private var showingAdd = false
    
    // Variables para el formulario de agregar
    @State private var newTitle = ""
    @State private var newAmountString = ""
    @State private var newIcon = "calendar"
    @State private var newDueDay = 5
    
    let icons = ["calendar", "wifi", "bolt.fill", "drop.fill", "house.fill", "graduationcap.fill", "car.fill", "iphone", "tv.fill", "gamecontroller.fill", "gym.bag.fill", "cross.case.fill"]
    
    var body: some View {
        List {
            if fixedCosts.isEmpty {
                ContentUnavailableView("Sin Costos Fijos", systemImage: "calendar.badge.exclamationmark", description: Text("Agrega tus gastos mensuales (Luz, Internet, Gimnasio) para que la App te recuerde pagarlos."))
            }
            
            ForEach(fixedCosts) { cost in
                // AHORA ES UN LINK A LA PANTALLA DE EDICIÓN
                NavigationLink(destination: EditFixedCostView(cost: cost)) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: cost.icon)
                                .foregroundStyle(.orange)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(cost.title)
                                .font(.headline)
                            Text("Vence el día \(cost.dueDay)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(cost.amount.formatted(.currency(code: "ARS")))
                            .bold()
                            .foregroundStyle(.primary)
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle("Costos Fijos")
        .toolbar {
            Button(action: { showingAdd = true }) {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                Form {
                    Section("Información") {
                        TextField("Nombre (ej: Internet)", text: $newTitle)
                        HStack {
                            Text("$").foregroundStyle(.secondary)
                            TextField("Monto Aprox", text: $newAmountString)
                                .keyboardType(.numberPad)
                        }
                    }
                    Section("Detalles") {
                        Picker("Día de Vencimiento", selection: $newDueDay) {
                            ForEach(1...31, id: \.self) { day in Text("Día \(day)").tag(day) }
                        }
                        Picker("Icono", selection: $newIcon) {
                            ForEach(icons, id: \.self) { icon in Label("Icono", systemImage: icon).tag(icon) }
                        }
                    }
                }
                .navigationTitle("Nuevo Costo")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showingAdd = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") { addItem() }
                        .disabled(newTitle.isEmpty || newAmountString.isEmpty)
                    }
                }
            }
        }
    }
    
    private func addItem() {
        let amount = Double(newAmountString) ?? 0.0
        let newCost = FixedCost(title: newTitle, amount: amount, icon: newIcon, dueDay: newDueDay)
        modelContext.insert(newCost)
        newTitle = ""; newAmountString = ""; newDueDay = 5
        showingAdd = false
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation { for index in offsets { modelContext.delete(fixedCosts[index]) } }
    }
}

// MARK: - VISTA DE EDICIÓN (NUEVA)
struct EditFixedCostView: View {
    @Bindable var cost: FixedCost
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let icons = ["calendar", "wifi", "bolt.fill", "drop.fill", "house.fill", "graduationcap.fill", "car.fill", "iphone", "tv.fill", "gamecontroller.fill", "gym.bag.fill", "cross.case.fill"]
    
    var body: some View {
        Form {
            Section("Información") {
                TextField("Nombre", text: $cost.title)
                TextField("Monto", value: $cost.amount, format: .currency(code: "ARS"))
                    .keyboardType(.decimalPad)
            }
            
            Section("Detalles") {
                Picker("Día de Vencimiento", selection: $cost.dueDay) {
                    ForEach(1...31, id: \.self) { day in Text("Día \(day)").tag(day) }
                }
                
                Picker("Icono", selection: $cost.icon) {
                    ForEach(icons, id: \.self) { icon in
                        Label("Icono", systemImage: icon).tag(icon)
                    }
                }
            }
            
            Section {
                Button(role: .destructive) {
                    modelContext.delete(cost)
                    dismiss()
                } label: {
                    Text("Eliminar Costo Fijo")
                }
            }
        }
        .navigationTitle("Editar Costo")
    }
}

#Preview {
    NavigationStack {
        FixedCostsView()
            .modelContainer(for: FixedCost.self, inMemory: true)
    }
}
