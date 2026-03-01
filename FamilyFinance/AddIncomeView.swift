import SwiftUI
import SwiftData

struct AddIncomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \ExpenseCategory.name) var categories: [ExpenseCategory]
    
    @EnvironmentObject var settings: FamilySettings

    @Query var ledgers: [FamilyLedger]
    
    enum IncomeField {
        case concepto, monto
    }

    @FocusState private var focusedField: IncomeField?
    @State private var amountString = ""
    
    @State private var title = ""
    @State private var date = Date()
    
    @State private var selectedCategoryName: String = "Varios"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Detalle del Ingreso") {
                    TextField("Concepto (ej. Sueldo)", text: $title)
                        .focused($focusedField, equals: .concepto)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .monto }

                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("Monto", text: $amountString)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .monto)
                            .submitLabel(.done)
                            .onChange(of: amountString) { oldValue, newValue in
                                amountString = formatCurrency(newValue)
                            }
                    }
                    
                    Picker("Categoría", selection: $selectedCategoryName) {
                        Text("Varios").tag("Varios")
                        ForEach(categories) { cat in
                            Text(cat.name).tag(cat.name)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Nuevo Ingreso")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        // 1. Limpiamos el texto para convertirlo en número (una sola vez)
                        let cleanAmount = amountString.replacingOccurrences(of: ".", with: "")
                        let finalAmount = Double(cleanAmount) ?? 0.0
                        
                        // 2. Creamos el ingreso
                        let newIncome = Income(
                            title: title,
                            amount: finalAmount,
                            date: date,
                            category: selectedCategoryName
                        )
                        
                        // 3. LA FIRMA DIGITAL 🔒 (Garantiza que el otro celu no lo vea)
                        newIncome.ownerId = settings.deviceID
                        newIncome.createdBy = settings.myName
                        
                        // 4. ATAMOS AL LIBRO COMPARTIDO
                        if let familyLedger = ledgers.first {
                            newIncome.ledger = familyLedger
                        } else {
                            let newLedger = FamilyLedger()
                            modelContext.insert(newLedger)
                            newIncome.ledger = newLedger
                        }
                        
                        // 5. Guardamos y cerramos
                        modelContext.insert(newIncome)
                        try? modelContext.save() // 👈 IMPORTANTE para forzar la sincronización con iCloud
                        dismiss()
                    }
                    .disabled(title.isEmpty || amountString.isEmpty)
                }
            }
            .onAppear {
                amountString = ""
                // Pequeño delay para que el teclado suba suave
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.focusedField = .concepto
                }
            }
        }
    }
    
    func formatCurrency(_ input: String) -> String {
        let clean = input.filter { "0123456789".contains($0) }
        guard let number = Int(clean) else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.locale = Locale(identifier: "es_AR")
        return formatter.string(from: NSNumber(value: number)) ?? ""
    }
    
    func saveIncome() {
        let cleanAmount = amountString.replacingOccurrences(of: ".", with: "")
        let value = Double(cleanAmount) ?? 0.0
        
        let newIncome = Income(
            title: title,
            amount: value,
            date: date,
            category: selectedCategoryName,
            ownerId: settings.deviceID // 👈 ASIGNAMOS TU ID
        )
        newIncome.createdBy = settings.myName // 👈 ASIGNAMOS TU NOMBRE ("Maca")
        
        if let familyLedger = ledgers.first {
            newIncome.ledger = familyLedger
        }
        
        modelContext.insert(newIncome)
        try? modelContext.save()
        dismiss()
    }
    
}
