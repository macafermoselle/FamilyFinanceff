import SwiftUI
import SwiftData

struct AddIncomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var amount = 0.0
    @State private var date = Date()
    
    // Sugerencias rápidas
    let suggestions = ["Sueldo Mensual", "Adelanto", "Ventas Extra", "Devolución"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Detalle") {
                    TextField("Concepto", text: $title)
                    
                    // Botones de sugerencia rápida
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(suggestions, id: \.self) { text in
                                Button(text) { title = text }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .tint(.green)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets()) // Para que ocupe todo el ancho
                    .padding(.vertical, 10)
                }
                
                Section("Monto") {
                    TextField("0.00", value: $amount, format: .currency(code: "ARS"))
                        .keyboardType(.decimalPad)
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    
                    DatePicker("Fecha de cobro", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Nuevo Ingreso")
            .toolbar {
                Button("Guardar") {
                    let newIncome = Income(title: title, amount: amount, date: date)
                    modelContext.insert(newIncome)
                    dismiss()
                }
                .disabled(title.isEmpty || amount == 0)
            }
        }
    }
}
