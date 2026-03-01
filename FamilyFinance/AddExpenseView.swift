import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query var cards: [CreditCard]
    
    // --- ESTO ES LO NUEVO PARA EL BILL TRACKER ---
    var preFilledCost: FixedCost?
    // ---------------------------------------------
    
    enum Field { case title, amount }
    @FocusState private var focusedField: Field?
    
    @State private var title = ""
    @State private var amountString = ""
    @State private var date = Date()
    @State private var category = "Varios"
    @State private var paymentMethod = "Efectivo / Débito"
    @State private var installments = 1
    @State private var selectedCard: CreditCard?
    
    @Query(sort: \ExpenseCategory.name) var availableCategories: [ExpenseCategory]
    let paymentMethods = ["Efectivo / Débito", "Tarjeta de Crédito"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Detalle") {
                    TextField("Concepto", text: $title)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .amount }
                    
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0", text: $amountString)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .amount)
                            .onChange(of: amountString) { _, newValue in
                                amountString = formatCurrency(newValue)
                            }
                    }
                    
                    Picker("Categoría", selection: $category) {
                        if availableCategories.isEmpty {
                            Text("Varios").tag("Varios")
                        } else {
                            ForEach(availableCategories) { cat in
                                Text(cat.name).tag(cat.name)
                            }
                        }
                    }
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }
                
                Section("Pago") {
                    Picker("Medio de Pago", selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.self) { Text($0) }
                    }
                    if paymentMethod == "Tarjeta de Crédito" {
                        if cards.isEmpty {
                            Text("No tienes tarjetas guardadas").foregroundStyle(.red).font(.caption)
                        } else {
                            Picker("Tarjeta", selection: $selectedCard) {
                                Text("Seleccionar...").tag(nil as CreditCard?)
                                ForEach(cards) { card in Text(card.name).tag(card as CreditCard?) }
                            }
                            Stepper("Cuotas: \(installments)", value: $installments, in: 1...24)
                        }
                    }
                }
            }
            .navigationTitle("Nuevo Gasto")
            .toolbar {
                Button("Guardar") { saveExpense() }
                    .disabled(title.isEmpty || amountString.isEmpty)
            }
            // --- LÓGICA DE PRECARGA AL ABRIR ---
            .onAppear {
                if let cost = preFilledCost {
                    // Si viene desde Vencimientos, llenamos todo solo
                    title = cost.title
                    let formatter = NumberFormatter()
                    formatter.numberStyle = .decimal
                    formatter.locale = Locale(identifier: "es_AR")
                    if let formatted = formatter.string(from: NSNumber(value: cost.amount)) {
                        amountString = formatted
                    }
                    category = "Servicios" // Asumimos que es servicio
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focusedField = .amount }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focusedField = .title }
                }
            }
        }
    }
    
    func formatCurrency(_ input: String) -> String {
        let cleanInput = input.filter { "0123456789".contains($0) }
        guard let number = Int(cleanInput) else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.locale = Locale(identifier: "es_AR")
        return formatter.string(from: NSNumber(value: number)) ?? ""
    }
    
    func saveExpense() {
        let cleanAmount = amountString.replacingOccurrences(of: ".", with: "")
        let finalAmount = Double(cleanAmount) ?? 0.0
        let newExpense = Expense(title: title, amount: finalAmount, date: date, category: category, createdBy: "Yo", paymentMethod: paymentMethod, installments: installments, card: selectedCard)
        modelContext.insert(newExpense)
        dismiss()
    }
}
