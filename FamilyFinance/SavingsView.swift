import SwiftUI
import SwiftData

struct SavingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var goals: [SavingGoal]
    @EnvironmentObject var settings: FamilySettings
    
    @StateObject private var shareManager = CloudSharingManager.shared
    
    @State private var showingAddGoal = false
    @State private var selectedGoalForDeposit: SavingGoal?
    @State private var selectedGoalForWithdraw: SavingGoal?
    @State private var showingBuyUSD = false
    
    var totalARS: Double { goals.filter { $0.currency == "ARS" }.reduce(0) { $0 + $1.currentAmount } }
    var totalUSD: Double { goals.filter { $0.currency == "USD" }.reduce(0) { $0 + $1.currentAmount } }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 15) {
                        TotalCard(title: "Pesos", amount: totalARS, color: .blue, code: "ARS")
                        TotalCard(title: "Dólares", amount: totalUSD, color: .green, code: "USD")
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    if !goals.isEmpty {
                        Button {
                            showingBuyUSD = true
                        } label: {
                            HStack {
                                Image(systemName: "dollarsign.arrow.circlepath")
                                Text("Comprar USD")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .foregroundStyle(.green)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    if goals.isEmpty {
                        ContentUnavailableView("Sin Ahorros", systemImage: "piggybank", description: Text("Creá tu primera meta para empezar a guardar."))
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 15) {
                            ForEach(goals) { goal in
                                NavigationLink(destination:
                                        SavingGoalDetailView(goal: goal)
                                            .environmentObject(settings)
                                    ) {
                                    SavingRowCard(goal: goal)
                                        .contextMenu {
                                            Button {
                                                selectedGoalForDeposit = goal
                                            } label: {
                                                Label("Depositar", systemImage: "arrow.down.circle")
                                            }
                                            
                                            Button {
                                                selectedGoalForWithdraw = goal
                                            } label: {
                                                Label("Retirar / Usar", systemImage: "arrow.up.circle")
                                            }
                                            
                                            Divider()
                                            
                                            Button(role: .destructive) {
                                                modelContext.delete(goal)
                                            } label: {
                                                Label("Eliminar Meta", systemImage: "trash")
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Mis Ahorros")
            .refreshable {
                shareManager.syncOnlyVencimientosYAhorros(context: modelContext)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
            .toolbar {
                Button(action: { showingAddGoal = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddSavingView()
            }
            .sheet(item: $selectedGoalForDeposit) { goal in
                DepositView(goal: goal)
                    .presentationDetents([.medium])
            }
            .sheet(item: $selectedGoalForWithdraw) { goal in
                WithdrawSavingsView(goal: goal)
                    .environmentObject(settings) // Aseguramos el entorno aquí
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingBuyUSD) {
                BuyUSDView(goals: goals)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

struct TotalCard: View {
    let title: String
    let amount: Double
    let color: Color
    let code: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(amount.formatted(.currency(code: code)))
                .font(.headline).bold()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct SavingRowCard: View {
    let goal: SavingGoal
    var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return goal.currentAmount / goal.targetAmount
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle().fill(goal.currency == "USD" ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Text(goal.currency == "USD" ? "USD" : "$")
                        .font(.caption).bold()
                        .foregroundStyle(goal.currency == "USD" ? .green : .blue)
                }
                VStack(alignment: .leading) {
                    Text(goal.name).font(.headline)
                    Text("Meta: \(goal.targetAmount.formatted(.currency(code: goal.currency)))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(goal.currentAmount.formatted(.currency(code: goal.currency)))
                    .bold()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(Color.gray.opacity(0.2)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 5).fill(goal.currency == "USD" ? Color.green : Color.blue)
                        .frame(width: min(CGFloat(progress) * geo.size.width, geo.size.width), height: 6)
                }
            }.frame(height: 6)
            HStack {
                Text("\(Int(progress * 100))%").font(.caption2).bold()
                Spacer()
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}

struct DepositView: View {
    @Bindable var goal: SavingGoal
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: FamilySettings
    
    @State private var amount = ""
    @State private var deductFromBalance = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Agregar dinero a \(goal.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(goal.currency == "USD" ? "US$" : "$")
                                .font(.title)
                                .bold()
                            TextField("0", text: $amount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                if goal.currency == "ARS" {
                    Section {
                        Toggle(isOn: $deductFromBalance) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Descontar de mi saldo")
                                    .font(.subheadline)
                                    .bold()
                                Text("Se registrará como un gasto en tu historial.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.orange)
                    }
                } else {
                    Section {
                        Text("Los depósitos en USD no afectan tu saldo disponible ya que se consideran movimientos de tus reservas de moneda extranjera.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Depositar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveDeposit()
                    }
                    .bold()
                    .disabled(amount.isEmpty)
                }
            }
        }
    }
    
    func saveDeposit() {
        let clean = amount.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(clean), value > 0 else { return }
        
        goal.currentAmount += value
        
        let movement = SavingMovement(
            amount: value,
            type: "Depósito",
            user: settings.myName,
            ownerId: settings.deviceID,
            note: ""
        )
        movement.goal = goal
        modelContext.insert(movement)
        
        if goal.currency == "ARS" && deductFromBalance {
            let newExpense = Expense(
                title: "Ahorro: \(goal.name)",
                amount: value,
                date: Date(),
                category: "Ahorros"
            )
            newExpense.ownerId = settings.deviceID
            newExpense.createdBy = settings.myName
            modelContext.insert(newExpense)
        }
        
        // 👇 EL HACK: Satélite con ticket incluido
        CloudSharingManager.shared.forcePushSavingToCloud(
            goalName: goal.name,
            currentAmount: goal.currentAmount,
            movAmount: value,
            movType: "Depósito",
            movUser: settings.myName,
            movOwner: settings.deviceID,
            movNote: ""
        )
        
        try? modelContext.save()
        dismiss()
    }
}

struct BuyUSDView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: FamilySettings
    
    var goals: [SavingGoal]
    
    @State private var arsAmount = ""
    @State private var exchangeRate = ""
    @State private var selectedGoal: SavingGoal?
    
    var usdResult: Double {
        let ars = Double(arsAmount.replacingOccurrences(of: ",", with: ".")) ?? 0
        let rate = Double(exchangeRate.replacingOccurrences(of: ",", with: ".")) ?? 1
        return rate > 0 ? ars / rate : 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos de la compra") {
                    TextField("Pesos a gastar", text: $arsAmount).keyboardType(.decimalPad)
                    TextField("Tipo de cambio", text: $exchangeRate).keyboardType(.decimalPad)
                }
                Section("Destino") {
                    Picker("Ahorro", selection: $selectedGoal) {
                        Text("Seleccionar meta").tag(nil as SavingGoal?)
                        ForEach(goals.filter({ $0.currency == "USD" })) { goal in
                            Text(goal.name).tag(goal as SavingGoal?)
                        }
                    }
                }
                if usdResult > 0 {
                    Section {
                        Text("Recibirás: \(usdResult.formatted(.currency(code: "USD")))")
                            .bold().foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Comprar USD")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        executePurchase()
                    }
                    .disabled(selectedGoal == nil || usdResult <= 0)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
    
    func executePurchase() {
        guard let goal = selectedGoal else { return }
        let ars = Double(arsAmount.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0
        let finalUSD = usdResult
        
        let purchaseExpense = Expense(
            title: "Compra USD para \(goal.name)",
            amount: ars,
            date: Date(),
            category: "Dólares"
        )
        purchaseExpense.ownerId = settings.deviceID
        purchaseExpense.createdBy = settings.myName
        modelContext.insert(purchaseExpense)
        
        goal.currentAmount += finalUSD
        let noteStr = "Compra a cotización \(exchangeRate)"
        
        let movement = SavingMovement(
            amount: finalUSD,
            type: "Depósito",
            user: settings.myName,
            ownerId: settings.deviceID,
            note: noteStr
        )
        movement.goal = goal
        modelContext.insert(movement)
        
        // 👇 EL HACK: Satélite con ticket incluido
        CloudSharingManager.shared.forcePushSavingToCloud(
            goalName: goal.name,
            currentAmount: goal.currentAmount,
            movAmount: finalUSD,
            movType: "Depósito",
            movUser: settings.myName,
            movOwner: settings.deviceID,
            movNote: noteStr
        )
        
        try? modelContext.save()
        dismiss()
    }
}
