import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Consultas para llenar los Pickers
    @Query var cards: [CreditCard]
    @Query(filter: #Predicate<Vacation> { $0.isActive == true }) var activeVacations: [Vacation]
    @Query(sort: \ExpenseCategory.name) var categories: [ExpenseCategory]
    
    // Configuración Familiar
    @EnvironmentObject var settings: FamilySettings
    @Query var ledgers: [FamilyLedger] // Para atar al libro compartido
    
    // 👇 VARIABLE CLAVE: Si esto no es nil, es que estamos pagando un servicio
    var preFilledCost: FixedCost?
    
    enum Field {
        case title, amount
    }
    
    @FocusState private var focusedField: Field?
    
    // Variables del Formulario
    @State private var title = ""
    @State private var amountString = ""
    @State private var date = Date()
    @State private var category = "Varios"
    @State private var paymentMethod = "Efectivo / Débito"
    @State private var installments = 1
    @State private var selectedCard: CreditCard?
    @State private var selectedVacation: String? = nil
    @State private var isHormiga: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. EL INTERRUPTOR (Solo visible si NO estamos pagando un servicio fijo)
                if preFilledCost == nil {
                    Section {
                        Toggle(isOn: $isHormiga) {
                            HStack {
                                Text("🐜")
                                VStack(alignment: .leading) {
                                    Text("Modo Hormiga")
                                    Text("Carga rápida de gastos chiquitos").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // 2. DATOS BÁSICOS
                Section(isHormiga ? "Gasto Rápido" : "Detalle del Gasto") {
                    TextField("Concepto", text: $title)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .amount
                        }
                    
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0", text: $amountString)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .amount)
                            .onChange(of: amountString) { oldValue, newValue in
                                amountString = formatCurrency(newValue)
                            }
                    }
                    
                    if !isHormiga {
                        Picker("Categoría", selection: $category) {
                            if categories.isEmpty {
                                Text("Sin categorías").tag("Varios")
                            } else {
                                Text("Varios").tag("Varios") // Opción por defecto segura
                                ForEach(categories) { cat in
                                    HStack {
                                        Image(systemName: cat.icon).foregroundStyle(.gray)
                                        Text(cat.name)
                                    }
                                    .tag(cat.name)
                                }
                            }
                        }
                        .pickerStyle(.navigationLink)
                        
                        DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    }
                }
                
                // 3. SECCIONES CONDICIONALES
                // (Ocultamos detalles complejos si es Hormiga)
                if !isHormiga {
                    Section("Pago") {
                        Picker("Medio de Pago", selection: $paymentMethod) {
                            Text("Efectivo / Débito").tag("Efectivo / Débito")
                            Text("Tarjeta de Crédito").tag("Tarjeta de Crédito")
                        }
                        
                        if paymentMethod == "Tarjeta de Crédito" {
                            Picker("Tarjeta", selection: $selectedCard) {
                                Text("Seleccionar...").tag(nil as CreditCard?)
                                ForEach(cards) { card in Text(card.name).tag(card as CreditCard?) }
                            }
                            Stepper("Cuotas: \(installments)", value: $installments, in: 1...24)
                        }
                    }
                    
                    Section("Modo Vacaciones") {
                        if activeVacations.isEmpty {
                            Text("No hay viajes activos").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Picker("¿Es parte de un viaje?", selection: $selectedVacation) {
                                Text("No, gasto normal").tag(nil as String?)
                                ForEach(activeVacations) { vacation in
                                    Text(vacation.name).tag(vacation.name as String?)
                                }
                            }
                        }
                    }
                }
            }
            // Título dinámico: Si pagamos servicio dice "Pagar X", sino "Nuevo Gasto"
            .navigationTitle(preFilledCost != nil ? "Confirmar Pago" : (isHormiga ? "Gasto Hormiga 🐜" : "Nuevo Gasto"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveExpense()
                    }
                    .disabled(title.isEmpty || amountString.isEmpty)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onAppear {
                // 👇 SI VIENE UN COSTO PRE-LLENADO (LUZ, GAS), COMPLETAMOS TODO
                if let cost = preFilledCost {
                    title = cost.title
                    
                    // Convertimos el monto guardado a string para editarlo
                    let amountAsInt = Int(cost.amount)
                    amountString = formatCurrency(String(amountAsInt))
                    
                    // Tratamos de adivinar la categoría, o dejamos Varios
                    if categories.contains(where: { $0.name == "Servicios" }) {
                        category = "Servicios"
                    } else if categories.contains(where: { $0.name == "Hogar" }) {
                        category = "Hogar"
                    } else {
                        category = "Varios"
                    }
                    
                    // Enfocamos el monto directamente para corregirlo rápido
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        focusedField = .amount
                    }
                } else {
                    // Si es gasto nuevo normal, enfocamos título
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if title.isEmpty { focusedField = .title }
                    }
                }
            }
        }
    }
    
    // MARK: - Lógica de Guardado
        func saveExpense() {
            let cleanAmount = amountString.replacingOccurrences(of: ".", with: "")
            let finalAmount = Double(cleanAmount) ?? 0.0
            
            // 1. Creamos el Gasto en el Historial
            let newExpense = Expense(
                title: title,
                amount: finalAmount,
                date: date,
                category: isHormiga ? "Hormiga" : category,
                isHormiga: isHormiga,
                createdBy: settings.myName, // Usamos tu nombre real
                paymentMethod: isHormiga ? "Efectivo" : paymentMethod,
                installments: isHormiga ? 1 : installments,
                card: isHormiga ? nil : selectedCard,
                vacationName: isHormiga ? nil : selectedVacation,
                isMine: true,
                ownerId: settings.deviceID
                
            )

            // 3. Insertamos el gasto
            modelContext.insert(newExpense)
            
            // 👇 4. LA MAGIA: ACTUALIZAMOS EL VENCIMIENTO Y DISPARAMOS AL SATÉLITE
            if let template = preFilledCost {
                // A. Actualizamos el monto base para que el mes que viene recuerde el nuevo precio
                template.amount = finalAmount
                
                // B. Lo marcamos como pagado (Check Verde ✅)
                template.markAsPaid(by: settings.myName)
                
                // C. DISPARAMOS EL HACK SATELITAL (Esta es la línea que faltaba)
                CloudSharingManager.shared.forcePushPaymentToCloud(costTitle: template.title, period: template.lastPaidPeriod, payer: settings.myName)
            }
            
            // 5. Guardamos todo
            try? modelContext.save()
            dismiss()
        }
    
    // MARK: - Formateo de Moneda
    func formatCurrency(_ input: String) -> String {
        let cleanInput = input.filter { "0123456789".contains($0) }
        guard let number = Int(cleanInput) else { return "" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.locale = Locale(identifier: "es_AR")
        
        return formatter.string(from: NSNumber(value: number)) ?? ""
    }
}
