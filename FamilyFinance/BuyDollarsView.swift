import SwiftUI

struct BuyDollarsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Recibimos la lista desde SavingsView
    let availableGoals: [SavingGoal]
    
    // CALLBACK ACTUALIZADO: Ahora recibe (USD, PESOS, ID)
    var onConfirm: (Double, Double, UUID) -> Void
    
    @State private var usdAmountString = ""
    @State private var exchangeRateString = ""
    @State private var selectedGoalID: UUID?
    
    var totalPesos: Double {
        let cleanUSD = usdAmountString.replacingOccurrences(of: ",", with: ".")
        let cleanRate = exchangeRateString.replacingOccurrences(of: ",", with: ".")
        let usd = Double(cleanUSD) ?? 0.0
        let rate = Double(cleanRate) ?? 0.0
        return usd * rate
    }
    
    // Filtramos solo USD de la lista que nos pasaron
    var usdGoals: [SavingGoal] {
        availableGoals.filter { $0.currency == "USD" }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Comprar Dólares")
                .font(.title2).bold().padding(.top)
            
            // CAMPOS
            VStack(spacing: 15) {
                HStack {
                    Text("USD").bold().foregroundStyle(.green).frame(width: 40)
                    TextField("Cantidad", text: $usdAmountString)
                        .keyboardType(.decimalPad)
                        .padding(10).background(Color.gray.opacity(0.1)).cornerRadius(8)
                }
                HStack {
                    Text("ARS").bold().foregroundStyle(.secondary).frame(width: 40)
                    TextField("Cotización", text: $exchangeRateString)
                        .keyboardType(.decimalPad)
                        .padding(10).background(Color.gray.opacity(0.1)).cornerRadius(8)
                }
            }.padding(.horizontal)
            
            // RESULTADO
            HStack {
                Text("Total a pagar:")
                Spacer()
                Text(totalPesos.formatted(.currency(code: "ARS")))
                    .font(.title3).bold().foregroundStyle(.red)
            }.padding(.horizontal)
            
            Divider()
            
            // SELECCIÓN (Usando la lista que nos pasaron)
            VStack(alignment: .leading) {
                Text("Guardar en:").font(.caption).foregroundStyle(.secondary).padding(.leading)
                
                if usdGoals.isEmpty {
                    Text("⚠️ No hay cajas en USD.").foregroundStyle(.orange).padding()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(usdGoals) { goal in
                                Button(action: { selectedGoalID = goal.id }) {
                                    VStack {
                                        Image(systemName: goal.icon).font(.title2)
                                        Text(goal.name).font(.caption2).lineLimit(1)
                                    }
                                    .padding().frame(width: 90, height: 70)
                                    .background(selectedGoalID == goal.id ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedGoalID == goal.id ? Color.green : Color.clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                            }
                        }.padding(.horizontal)
                    }
                }
            }
            
            Spacer()
            
            // BOTONES
            HStack(spacing: 15) {
                Button("Cancelar") { dismiss() }
                    .foregroundStyle(.red)
                    .padding().frame(maxWidth: .infinity).background(Color.red.opacity(0.1)).cornerRadius(12)
                
                Button("Confirmar") {
                    // 1. Esconder teclado
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    
                    let cleanUSD = usdAmountString.replacingOccurrences(of: ",", with: ".")
                    let usdAmount = Double(cleanUSD) ?? 0.0
                    
                    if let goalID = selectedGoalID {
                        // 3. ENVIAR LOS 3 DATOS AHORA SÍ
                        onConfirm(usdAmount, totalPesos, goalID)
                        dismiss()
                    }
                }
                .padding().frame(maxWidth: .infinity).background(Color.green).foregroundColor(.white).cornerRadius(12)
                .disabled(totalPesos == 0 || selectedGoalID == nil)
            }.padding()
        }
        .background(Color(uiColor: .systemBackground))
    }
}
