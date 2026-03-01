import SwiftUI
import SwiftData

// 1. VISTA PRINCIPAL (Checklist)
struct FixedIncomesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FixedIncome.dayOfMonth) var fixedIncomes: [FixedIncome]
    
    @State private var showingAdd = false
    @State private var incomeToCollect: FixedIncome?
    
    var body: some View {
        List {
            // SECCIÓN 1: PENDIENTES
            Section("Pendientes de Cobro") {
                if fixedIncomes.filter({ !$0.isCollected() }).isEmpty {
                    Text("¡Todo cobrado este mes! 💰")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
                
                ForEach(fixedIncomes.filter { !$0.isCollected() }) { income in
                    HStack {
                        // Día
                        VStack {
                            Text("\(income.dayOfMonth)")
                                .font(.title3).bold()
                                .foregroundStyle(.white)
                        }
                        .frame(width: 40, height: 40)
                        .background(Color.green.opacity(0.8))
                        .clipShape(Circle())
                        
                        // Detalle
                        NavigationLink(destination: EditFixedIncomeView(income: income)) {
                            VStack(alignment: .leading) {
                                Text(income.name)
                                    .font(.headline)
                                Text(income.amount.formatted(.currency(code: "ARS")))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        // Botón Cobrar
                        Button("Cobrar") {
                            incomeToCollect = income
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // SECCIÓN 2: COBRADOS
            Section("Ya cobrados este mes") {
                ForEach(fixedIncomes.filter { $0.isCollected() }) { income in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                        
                        NavigationLink(destination: EditFixedIncomeView(income: income)) {
                            VStack(alignment: .leading) {
                                Text(income.name)
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                                Text(income.amount.formatted(.currency(code: "ARS")))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteIncomes)
            }
        }
        .navigationTitle("Ingresos Fijos")
        .toolbar {
            Button(action: { showingAdd = true }) {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddFixedIncomeView()
        }
        .alert("Confirmar Cobro", isPresented: Binding(
            get: { incomeToCollect != nil },
            set: { if !$0 { incomeToCollect = nil } }
        )) {
            Button("Cancelar", role: .cancel) { }
            Button("Confirmar") {
                if let income = incomeToCollect {
                    collectIncome(income)
                }
            }
        } message: {
            if let income = incomeToCollect {
                Text("Se agregará \(income.amount.formatted(.currency(code: "ARS"))) a tu saldo disponible.")
            }
        }
    }
    
    private func collectIncome(_ fixedIncome: FixedIncome) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-yyyy"
        fixedIncome.lastCollectedMonth = formatter.string(from: Date())
        
        let newIncome = Income(
            title: fixedIncome.name,
            amount: fixedIncome.amount,
            date: Date()
        )
        modelContext.insert(newIncome)
        incomeToCollect = nil
    }
    
    private func deleteIncomes(offsets: IndexSet) {
        withAnimation {
            let collected = fixedIncomes.filter { $0.isCollected() }
            for index in offsets {
                modelContext.delete(collected[index])
            }
        }
    }
}

// 2. VISTA AGREGAR
struct AddFixedIncomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var amount = 0.0
    @State private var dayOfMonth = 1
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre (ej. Sueldo)", text: $name)
                TextField("Monto habitual", value: $amount, format: .currency(code: "ARS"))
                    .keyboardType(.decimalPad)
                
                // CORRECCIÓN AQUÍ: Usamos 'day' en lugar de '$0'
                Picker("Día estimado de cobro", selection: $dayOfMonth) {
                    ForEach(1...31, id: \.self) { day in
                        Text("Día \(day)").tag(day)
                    }
                }
            }
            .navigationTitle("Nuevo Ingreso Fijo")
            .toolbar {
                Button("Guardar") {
                    let new = FixedIncome(name: name, amount: amount, dayOfMonth: dayOfMonth)
                    modelContext.insert(new)
                    dismiss()
                }
                .disabled(name.isEmpty || amount == 0)
            }
        }
    }
}

// 3. VISTA EDITAR
struct EditFixedIncomeView: View {
    @Bindable var income: FixedIncome
    
    var body: some View {
        Form {
            Section("Detalle") {
                TextField("Nombre", text: $income.name)
                TextField("Monto actualizado", value: $income.amount, format: .currency(code: "ARS"))
                    .keyboardType(.decimalPad)
                    .foregroundStyle(.green)
                
                // CORRECCIÓN AQUÍ TAMBIÉN
                Picker("Día estimado", selection: $income.dayOfMonth) {
                    ForEach(1...31, id: \.self) { day in
                        Text("Día \(day)").tag(day)
                    }
                }
            }
            Section {
                Text("Al cambiar el monto aquí, los próximos cobros usarán este valor nuevo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Editar Ingreso Fijo")
    }
}
