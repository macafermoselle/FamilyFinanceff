import SwiftUI
import SwiftData
import Charts

struct FutureProjectionsView: View {
    @Query var expenses: [Expense]
    @Query var cards: [CreditCard]
    @Environment(\.modelContext) var modelContext
    
    // Estados para el pago rápido desde esta misma pantalla
    @State private var showingFastPaymentAlert = false
    @State private var editedAmount: String = ""
    @State private var selectedCardForPayment: String = ""
    
    struct MonthlyDebt: Identifiable {
        var id = UUID()
        var monthName: String
        var amount: Double
        var date: Date
        var isPaid: Bool
    }
    
    let currentMonth = Date()
    
    // --- LÓGICA DE PROYECCIONES PARA EL GRÁFICO Y LISTA ---
    
    var projections: [MonthlyDebt] {
        var data: [MonthlyDebt] = []
        let calendar = Calendar.current
        let today = Date()
        
        for offset in 0...11 {
            if let futureDate = calendar.date(byAdding: .month, value: offset, to: today) {
                let monthlyTotal = expenses.totalCreditDebt(for: futureDate)
                
                // Si el monto es 0, el mes ya está "saldado" visualmente
                if monthlyTotal <= 0 {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "es_AR")
                    formatter.dateFormat = "MMM"
                    data.append(MonthlyDebt(monthName: formatter.string(from: futureDate).uppercased(), amount: 0, date: futureDate, isPaid: true))
                    continue
                }
                
                // Chequeamos si el mes está saldado
                let creditExpenses = expenses.filter { $0.paymentMethod == "Tarjeta de Crédito" }
                let namesInMonth = Set(creditExpenses.compactMap { $0.card?.name })
                
                var allPaid = !namesInMonth.isEmpty
                for name in namesInMonth {
                    let cardDebt = expenses.filter({ $0.card?.name == name }).totalCreditDebt(for: futureDate)
                    if cardDebt > 0 {
                        let isCardPaid = expenses.contains {
                            $0.category == "Finanzas" &&
                            $0.title.localizedCaseInsensitiveContains("Pago Tarjeta \(name)") &&
                            calendar.isDate($0.date, equalTo: futureDate, toGranularity: .month)
                        }
                        if !isCardPaid { allPaid = false; break }
                    }
                }
                
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "es_AR")
                formatter.dateFormat = "MMM"
                let monthString = formatter.string(from: futureDate).uppercased()
                
                data.append(MonthlyDebt(monthName: monthString, amount: monthlyTotal, date: futureDate, isPaid: allPaid))
            }
        }
        return data
    }
    
    // --- LÓGICA DE TARJETAS PENDIENTES ---
    
    struct PendingCard: Identifiable {
        let id = UUID()
        let name: String
        let amount: Double
    }
    
    var tarjetasPendientesHoy: [PendingCard] {
        let calendar = Calendar.current
        let creditExpenses = expenses.filter { $0.paymentMethod == "Tarjeta de Crédito" }
        let nombresDeTarjetas = Set(creditExpenses.compactMap { $0.card?.name })
        
        var pendientes: [PendingCard] = []
        
        for name in nombresDeTarjetas {
            let gastosDeEstaTarjeta = expenses.filter { $0.card?.name == name }
            let deudaDeTarjeta = gastosDeEstaTarjeta.totalCreditDebt(for: currentMonth)
            
            if deudaDeTarjeta > 0 {
                let yaPagada = expenses.contains {
                    $0.category == "Finanzas" &&
                    $0.title.localizedCaseInsensitiveContains("Pago Tarjeta \(name)") &&
                    calendar.isDate($0.date, equalTo: currentMonth, toGranularity: .month)
                }
                
                if !yaPagada {
                    pendientes.append(PendingCard(name: name, amount: deudaDeTarjeta))
                }
            }
        }
        return pendientes.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 1. SECCIÓN DE PAGO RÁPIDO
                    if !tarjetasPendientesHoy.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pendientes de \(currentMonth.formatted(.dateTime.month(.wide)).capitalized)")
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            ForEach(tarjetasPendientesHoy) { card in
                                HStack {
                                    Image(systemName: "creditcard.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.orange)
                                    
                                    VStack(alignment: .leading) {
                                        Text(card.name)
                                            .font(.subheadline).bold()
                                        Text(card.amount.formatted(.currency(code: "ARS")))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Pagar") {
                                        selectedCardForPayment = card.name
                                        editedAmount = String(format: "%.0f", card.amount)
                                        showingFastPaymentAlert = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                                    .controlSize(.small)
                                }
                                .padding()
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 2)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // 2. GRÁFICO DE PROYECCIONES
                    VStack(alignment: .leading) {
                        Text("Deuda Total Proyectada")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        if !projections.filter({ $0.amount > 0 }).isEmpty {
                            Chart(projections) { item in
                                BarMark(
                                    x: .value("Mes", item.monthName),
                                    y: .value("Monto", item.amount)
                                )
                                .foregroundStyle(item.isPaid ? Color.green.gradient : Color.blue.gradient)
                                .opacity(item.isPaid ? 0.6 : 1.0)
                                .cornerRadius(5)
                            }
                            .frame(height: 180)
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(15)
                        } else {
                            ContentUnavailableView("Sin deudas", systemImage: "sparkles")
                                .frame(height: 180)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 3. DETALLE MES A MES
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Detalle por Mes")
                            .font(.headline)
                            .padding()
                        
                        ForEach(projections) { item in
                            NavigationLink(destination: DetailedMonthView(targetDate: item.date)) {
                                HStack {
                                    Text(item.monthName)
                                        .bold()
                                        .frame(width: 50, alignment: .leading)
                                        .foregroundStyle(item.isPaid ? .green : .primary)
                                    
                                    if item.isPaid {
                                        Text("PAGADO")
                                            .font(.system(size: 8, weight: .black))
                                            .foregroundStyle(.green)
                                            .padding(.horizontal, 4)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(item.amount.formatted(.currency(code: "ARS")))
                                        .font(.subheadline)
                                        .foregroundStyle(item.isPaid ? .secondary : .primary)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                            }
                            Divider()
                        }
                    }
                    .cornerRadius(15)
                    .padding()
                }
            }
            .navigationTitle("Futuro")
            .background(Color(uiColor: .systemGroupedBackground))
            .alert("Pagar Tarjeta \(selectedCardForPayment)", isPresented: $showingFastPaymentAlert) {
                TextField("Monto", text: $editedAmount).keyboardType(.decimalPad)
                Button("Cancelar", role: .cancel) {}
                Button("Confirmar") { confirmarPagoRapido() }
            }
        }
    }
    
    func confirmarPagoRapido() {
        let amount = Double(editedAmount) ?? 0
        let newPayment = Expense(
            title: "Pago Tarjeta \(selectedCardForPayment) - \(currentMonth.formatted(.dateTime.month(.wide)).capitalized)",
            amount: amount,
            date: currentMonth,
            category: "Finanzas",
            isHormiga: false,
            createdBy: "Yo",
            paymentMethod: "Efectivo / Débito",
            installments: 1
        )
        modelContext.insert(newPayment)
    }
}

// MARK: - VISTA DE DETALLE COMPLETA
struct DetailedMonthView: View {
    let targetDate: Date
    @Query var allExpenses: [Expense]
    @Environment(\.modelContext) var modelContext
    
    @State private var showingPaymentAlert = false
    @State private var editedAmount: String = ""
    @State private var selectedCardForPayment: String = ""
    
    // Lógica para agrupar movimientos por tarjeta
    var groupedMovements: [String: [(expense: Expense, installmentNumber: Int, amount: Double)]] {
        var groups: [String: [(Expense, Int, Double)]] = [:]
        let calendar = Calendar.current
        let creditExpenses = allExpenses.filter { $0.paymentMethod == "Tarjeta de Crédito" }
        
        for expense in creditExpenses {
            let cardName = expense.card?.name ?? "Sin Tarjeta"
            let closingDay = expense.card?.closingDay ?? 24
            var startPaymentDate = expense.date
            
            if calendar.component(.day, from: expense.date) > closingDay {
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: expense.date) {
                    startPaymentDate = nextMonth
                }
            }
            
            if let endPaymentDate = calendar.date(byAdding: .month, value: expense.installments - 1, to: startPaymentDate) {
                let isAfterStart = calendar.compare(targetDate, to: startPaymentDate, toGranularity: .month) != .orderedAscending
                let isBeforeEnd = calendar.compare(targetDate, to: endPaymentDate, toGranularity: .month) != .orderedDescending
                
                if isAfterStart && isBeforeEnd {
                    let startComps = calendar.dateComponents([.year, .month], from: startPaymentDate)
                    let targetComps = calendar.dateComponents([.year, .month], from: targetDate)
                    if let start = calendar.date(from: startComps), let target = calendar.date(from: targetComps) {
                        let monthsDiff = calendar.dateComponents([.month], from: start, to: target).month ?? 0
                        let installmentAmount = expense.amount / Double(max(1, expense.installments))
                        if groups[cardName] == nil { groups[cardName] = [] }
                        groups[cardName]?.append((expense, monthsDiff + 1, installmentAmount))
                    }
                }
            }
        }
        return groups
    }

    var body: some View {
        List {
            if groupedMovements.isEmpty {
                ContentUnavailableView("Sin gastos", systemImage: "creditcard")
            } else {
                ForEach(groupedMovements.keys.sorted(), id: \.self) { cardName in
                    let movements = groupedMovements[cardName] ?? []
                    let total = movements.reduce(0) { $0 + $1.amount }
                    let isPaid = checkIfPaid(card: cardName)
                    
                    Section(header: Text(cardName)) {
                        ForEach(movements, id: \.expense.id) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.expense.title).font(.subheadline).bold()
                                    Text("Cuota \(item.installmentNumber) de \(item.expense.installments)").font(.caption2).foregroundStyle(.blue)
                                }
                                Spacer()
                                Text(item.amount.formatted(.currency(code: "ARS")))
                            }
                        }
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total \(cardName)").font(.caption).foregroundStyle(.secondary)
                                Text(total.formatted(.currency(code: "ARS")))
                                    .bold()
                                    .foregroundStyle(isPaid ? .green : .red)
                            }
                            Spacer()
                            if isPaid {
                                Label("Pagada", systemImage: "checkmark.circle.fill").foregroundStyle(.green).bold()
                            } else {
                                Button("Pagar") {
                                    selectedCardForPayment = cardName
                                    editedAmount = String(format: "%.0f", total)
                                    showingPaymentAlert = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(targetDate.formatted(.dateTime.month(.wide).year()))
        .alert("Pagar Tarjeta", isPresented: $showingPaymentAlert) {
            TextField("Monto", text: $editedAmount).keyboardType(.decimalPad)
            Button("Cancelar", role: .cancel) {}
            Button("Confirmar") { confirmarPago(card: selectedCardForPayment) }
        }
    }
    
    func checkIfPaid(card: String) -> Bool {
        allExpenses.contains {
            $0.category == "Finanzas" &&
            $0.title.localizedCaseInsensitiveContains("Pago Tarjeta \(card)") &&
            Calendar.current.isDate($0.date, equalTo: targetDate, toGranularity: .month)
        }
    }
    
    func confirmarPago(card: String) {
        let amount = Double(editedAmount) ?? 0
        let monthName = targetDate.formatted(.dateTime.month(.wide)).capitalized
        let newPayment = Expense(
            title: "Pago Tarjeta \(card) - \(monthName)",
            amount: amount,
            date: targetDate,
            category: "Finanzas",
            isHormiga: false,
            createdBy: "Yo",
            paymentMethod: "Efectivo / Débito",
            installments: 1
        )
        modelContext.insert(newPayment)
    }
}
