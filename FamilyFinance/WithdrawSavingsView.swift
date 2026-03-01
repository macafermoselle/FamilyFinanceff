import SwiftUI
import SwiftData

struct WithdrawSavingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // 👇 AGREGADO: Necesitamos los settings para saber quién hace el retiro
    @EnvironmentObject var settings: FamilySettings
    
    @Bindable var goal: SavingGoal
    
    @State private var amountString = ""
    @State private var addToBalance = true // Por defecto, sumamos al saldo
    @State private var exchangeRate = "" // Solo para USD
    
    var body: some View {
        NavigationStack {
            Form {
                Section("¿Cuánto vas a retirar?") {
                    HStack {
                        Text(goal.currency)
                            .bold()
                            .foregroundStyle(goal.currency == "USD" ? .green : .blue)
                        
                        TextField("Monto", text: $amountString)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }
                    
                    Text("Disponible: \(goal.currentAmount.formatted(.currency(code: goal.currency)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Destino") {
                    Toggle("Sumar a mi Saldo Disponible", isOn: $addToBalance)
                    
                    if addToBalance && goal.currency == "USD" {
                        VStack(alignment: .leading) {
                            Text("Cotización de Venta")
                                .font(.caption).foregroundStyle(.secondary)
                            
                            HStack {
                                Text("$")
                                TextField("Ej: 1100", text: $exchangeRate)
                                    .keyboardType(.decimalPad)
                            }
                        }
                    }
                }
                
                if addToBalance {
                    Section("Resultado") {
                        if goal.currency == "USD" {
                            let totalPesos = (Double(amountString.replacingOccurrences(of: ",", with: ".")) ?? 0) * (Double(exchangeRate.replacingOccurrences(of: ",", with: ".")) ?? 0)
                            Text("Se agregarán **\(totalPesos.formatted(.currency(code: "ARS")))** a tus ingresos.")
                                .font(.caption)
                        } else {
                            Text("Se generará un ingreso por este monto.")
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Retirar Dinero")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        processWithdrawal()
                    }
                    .disabled(amountString.isEmpty)
                }
            }
        }
    }
    
    func processWithdrawal() {
        let cleanAmount = amountString.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(cleanAmount), amount > 0 else { return }
        
        let actualWithdrawal = min(amount, goal.currentAmount)
        goal.currentAmount -= actualWithdrawal
        
        let note = addToBalance ? "Enviado al saldo" : "Retiro directo"
        
        let movement = SavingMovement(
            amount: actualWithdrawal,
            type: "Retiro",
            user: settings.myName,
            ownerId: settings.deviceID,
            note: note
        )
        movement.goal = goal
        modelContext.insert(movement)
        
        if addToBalance {
            var finalIncomeAmount = actualWithdrawal
            var title = "Retiro de: \(goal.name)"
            
            if goal.currency == "USD" {
                let rate = Double(exchangeRate.replacingOccurrences(of: ",", with: ".")) ?? 0
                finalIncomeAmount = actualWithdrawal * rate
                title += " (Venta USD a \(exchangeRate))"
            }
            
            if finalIncomeAmount > 0 {
                let newIncome = Income(title: title, amount: finalIncomeAmount, date: Date())
                newIncome.ownerId = settings.deviceID
                newIncome.createdBy = settings.myName
                modelContext.insert(newIncome)
            }
        }
        
        // 👇 EL HACK: Pasamos todos los datos del ticket al satélite
        CloudSharingManager.shared.forcePushSavingToCloud(
            goalName: goal.name,
            currentAmount: goal.currentAmount,
            movAmount: actualWithdrawal,
            movType: "Retiro",
            movUser: settings.myName,
            movOwner: settings.deviceID,
            movNote: note
        )
        
        try? modelContext.save()
        dismiss()
    }
}
