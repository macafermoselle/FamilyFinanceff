import SwiftUI
import SwiftData

struct AddSavingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query var ledgers: [FamilyLedger]
    
    @State private var name = ""
    @State private var targetAmountString = ""
    @State private var currentAmountString = ""
    @State private var deadline = Date()
    @State private var icon = "airplane"
    
    @State private var selectedCurrency = "ARS"
    
    let icons = ["airplane", "car.fill", "house.fill", "gift.fill", "gamecontroller.fill", "tv.fill", "graduationcap.fill", "star.fill", "heart.fill"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Meta") {
                    TextField("Nombre (ej. Viaje al Sur)", text: $name)
                    
                    HStack {
                        Text(selectedCurrency == "USD" ? "US$" : "$")
                            .foregroundStyle(.secondary)
                        TextField("Objetivo Total", text: $targetAmountString)
                            .keyboardType(.numberPad)
                    }
                    
                    Picker("Moneda", selection: $selectedCurrency) {
                        Text("Pesos (ARS)").tag("ARS")
                        Text("Dólares (USD)").tag("USD")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Estado Actual") {
                    HStack {
                        Text(selectedCurrency == "USD" ? "US$" : "$")
                            .foregroundStyle(.secondary)
                        TextField("Ya ahorrado", text: $currentAmountString)
                            .keyboardType(.numberPad)
                    }
                    DatePicker("Fecha límite", selection: $deadline, displayedComponents: .date)
                }
                
                Section("Ícono") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(icons, id: \.self) { item in
                                Image(systemName: item)
                                    .padding(10)
                                    .background(icon == item ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                    .clipShape(Circle())
                                    .foregroundStyle(icon == item ? .blue : .primary)
                                    .onTapGesture { icon = item }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .navigationTitle("Nuevo Ahorro")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveSaving()
                    }
                    .disabled(name.isEmpty || targetAmountString.isEmpty)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
    
    func saveSaving() {
        let cleanTarget = targetAmountString.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        let cleanCurrent = currentAmountString.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        
        let target = Double(cleanTarget) ?? 0.0
        let current = Double(cleanCurrent) ?? 0.0
        
        let newSaving = SavingGoal(
            name: name,
            targetAmount: target,
            currentAmount: current,
            deadline: deadline,
            icon: icon,
            currency: selectedCurrency
        )
        
        if let familyLedger = ledgers.first {
            newSaving.ledger = familyLedger
        } else {
            let newLedger = FamilyLedger()
            modelContext.insert(newLedger)
            newSaving.ledger = newLedger
        }
        
        modelContext.insert(newSaving)
        try? modelContext.save()
        dismiss()
    }
}

struct SavingGoalDetailView: View {
    @Bindable var goal: SavingGoal
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: FamilySettings
    
    @Query(sort: \SavingMovement.date, order: .reverse) var allMovements: [SavingMovement]
    
    @StateObject private var shareManager = CloudSharingManager.shared
    
    // 👇 EL ARREGLO ESTÁ ACÁ: Filtramos por NOMBRE en lugar del objeto exacto
    var goalMovements: [SavingMovement] {
        allMovements.filter { $0.goal?.name == goal.name }
    }
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: goal.icon)
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                    
                    Text(goal.currentAmount.formatted(.currency(code: goal.currency)))
                        .font(.largeTitle).bold()
                    
                    ProgressView(value: goal.currentAmount, total: goal.targetAmount)
                        .tint(.blue)
                    
                    Text("Meta: \(goal.targetAmount.formatted(.currency(code: goal.currency)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            
            Section("Historial de movimientos") {
                if goalMovements.isEmpty {
                    Text("No hay movimientos aún")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(goalMovements) { move in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(move.type)
                                    .font(.subheadline).bold()
                                HStack(spacing: 4) {
                                    Text(move.user).bold()
                                    Text("•")
                                    Text(move.date.formatted(date: .abbreviated, time: .shortened))
                                }
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(move.type == "Depósito" ? "+" : "-") \(move.amount.formatted(.currency(code: goal.currency)))")
                                .font(.subheadline).bold()
                                .foregroundStyle(move.type == "Depósito" ? .green : .red)
                        }
                        .swipeActions(edge: .trailing) {
                            if move.ownerId == settings.deviceID {
                                Button(role: .destructive) {
                                    deleteMovement(move)
                                } label: {
                                    Label("Borrar", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(goal.name)
        .refreshable {
            // 👇 AHORA SÍ: Usamos el Francotirador que sobreescribe montos
            shareManager.syncOnlyVencimientosYAhorros(context: modelContext)
            // Le damos 1.5 seg para que termine de procesar antes de ocultar la ruedita
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
    }
    
    func deleteMovement(_ movement: SavingMovement) {
        // 1. Reajustamos el saldo del ahorro antes de borrar el registro
        if movement.type == "Depósito" {
            goal.currentAmount -= movement.amount
        } else {
            goal.currentAmount += movement.amount
        }
        
        // 2. Lo borramos de la base de datos local
        modelContext.delete(movement)
        
        // 3. EL HACK SATELITAL INVERSO (Avisarle a la nube del cambio para el otro celular)
        CloudSharingManager.shared.forcePushSavingToCloud(goalName: goal.name, currentAmount: goal.currentAmount)
        
        try? modelContext.save()
    }
}
