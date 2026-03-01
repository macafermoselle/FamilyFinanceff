import SwiftUI
import SwiftData
import Charts

struct FutureProjectionsView: View {
    @Query var expenses: [Expense] // Traemos todos los gastos
    @Query var cards: [CreditCard] // Traemos las tarjetas para el detalle
    
    // Estructura para el gráfico
    struct MonthlyDebt: Identifiable {
        var id = UUID()
        var monthName: String
        var amount: Double
        var date: Date // Para ordenar
    }
    
    @State private var selectedMonth: MonthlyDebt? // Para mostrar el detalle
    
    // CÁLCULO MÁGICO DEL FUTURO
    var projections: [MonthlyDebt] {
        var data: [MonthlyDebt] = []
        let calendar = Calendar.current
        let today = Date()
        
        // Calculamos para los próximos 12 meses
        for offset in 0...11 {
            if let futureDate = calendar.date(byAdding: .month, value: offset, to: today) {
                
                // Filtramos gastos de tarjeta que impacten en ESA fecha futura
                let monthlyTotal = expenses.filter { $0.paymentMethod == "Tarjeta de Crédito" }.reduce(0.0) { partialResult, expense in
                    
                    // Lógica de cuotas (reutilizamos la que ya funciona)
                    let closingDay = expense.card?.closingDay ?? 24
                    var startPaymentDate = expense.date
                    let dayOfPurchase = calendar.component(.day, from: expense.date)
                    
                    // Ajuste por cierre
                    if dayOfPurchase > closingDay {
                        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: expense.date) {
                            startPaymentDate = nextMonth
                        }
                    }
                    
                    // Fechas inicio y fin de la deuda
                    if let endPaymentDate = calendar.date(byAdding: .month, value: expense.installments - 1, to: startPaymentDate) {
                        
                        // Chequeamos si 'futureDate' cae dentro de la deuda
                        let isAfterStart = calendar.compare(futureDate, to: startPaymentDate, toGranularity: .month) != .orderedAscending
                        let isBeforeEnd = calendar.compare(futureDate, to: endPaymentDate, toGranularity: .month) != .orderedDescending
                        
                        if isAfterStart && isBeforeEnd {
                            return partialResult + (expense.amount / Double(expense.installments))
                        }
                    }
                    return partialResult
                }
                
                // Formato del nombre del mes (ej: "ABR")
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "es_AR")
                formatter.dateFormat = "MMM"
                let monthString = formatter.string(from: futureDate).uppercased()
                
                data.append(MonthlyDebt(monthName: monthString, amount: monthlyTotal, date: futureDate))
            }
        }
        return data
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Tu Deuda Futura")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.top)
                    
                    // 1. GRÁFICO DE BARRAS
                    if !projections.filter({ $0.amount > 0 }).isEmpty {
                        Chart(projections) { item in
                            BarMark(
                                x: .value("Mes", item.monthName),
                                y: .value("Monto", item.amount)
                            )
                            .foregroundStyle(Color.blue.gradient)
                            .cornerRadius(5)
                            .annotation(position: .top) {
                                Text(item.amount.formatted(.currency(code: "ARS").precision(.fractionLength(0))))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 250)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                    } else {
                        ContentUnavailableView("Sin deudas futuras", systemImage: "hand.thumbsup.fill", description: Text("No tienes cuotas pendientes para los próximos meses."))
                    }
                    
                    // 2. LISTA DETALLADA (Interactiva)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Detalle mes a mes")
                            .font(.headline)
                            .padding()
                        
                        ForEach(projections) { item in
                            // Al tocar una fila, abrimos el detalle de ESE mes
                            NavigationLink(destination: DetailedMonthView(targetDate: item.date, expenses: expenses, cards: cards)) {
                                HStack {
                                    Text(item.monthName)
                                        .bold()
                                        .frame(width: 50, alignment: .leading)
                                        .foregroundStyle(.primary)
                                    
                                    // Barrita visual simple
                                    GeometryReader { geo in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(width: item.amount > 0 ? (item.amount / (projections.map{$0.amount}.max() ?? 1)) * geo.size.width : 0)
                                    }
                                    .frame(height: 6)
                                    
                                    Spacer()
                                    
                                    Text(item.amount.formatted(.currency(code: "ARS")))
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color.white)
                                .contentShape(Rectangle()) // Hace que todo el renglón sea tocable
                            }
                            Divider()
                        }
                    }
                    .cornerRadius(15)
                    .padding()
                }
            }
            .navigationTitle("Proyecciones")
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

// MARK: - VISTA DE DETALLE (EL SIMULADOR AUTOMÁTICO)
// Esta vista recibe una fecha y te dice QUÉ cuotas pagas ese mes
struct DetailedMonthView: View {
    let targetDate: Date
    let expenses: [Expense]
    let cards: [CreditCard]
    
    var movements: [(expense: Expense, installmentNumber: Int, amount: Double, cardName: String)] {
        var list: [(Expense, Int, Double, String)] = []
        let calendar = Calendar.current
        
        let creditExpenses = expenses.filter { $0.paymentMethod == "Tarjeta de Crédito" }
        
        for expense in creditExpenses {
            let cardName = expense.card?.name ?? "Desconocida"
            let closingDay = expense.card?.closingDay ?? 24
            var startPaymentDate = expense.date
            let dayOfPurchase = calendar.component(.day, from: expense.date)
            
            if dayOfPurchase > closingDay {
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: expense.date) {
                    startPaymentDate = nextMonth
                }
            }
            
            if let endPaymentDate = calendar.date(byAdding: .month, value: expense.installments - 1, to: startPaymentDate) {
                // Comparamos Año y Mes
                let startComps = calendar.dateComponents([.year, .month], from: startPaymentDate)
                let endComps = calendar.dateComponents([.year, .month], from: endPaymentDate)
                let targetComps = calendar.dateComponents([.year, .month], from: targetDate)
                
                if let start = calendar.date(from: startComps),
                   let end = calendar.date(from: endComps),
                   let target = calendar.date(from: targetComps) {
                    
                    if target >= start && target <= end {
                        let monthsDiff = calendar.dateComponents([.month], from: start, to: target).month ?? 0
                        let currentInstallment = monthsDiff + 1
                        let installmentAmount = expense.amount / Double(expense.installments)
                        
                        list.append((expense, currentInstallment, installmentAmount, cardName))
                    }
                }
            }
        }
        return list
    }
    
    var body: some View {
        List {
            Section("Total a Pagar") {
                HStack {
                    Text("Total Estimado")
                    Spacer()
                    Text(movements.reduce(0){$0 + $1.amount}.formatted(.currency(code: "ARS")))
                        .bold()
                        .foregroundStyle(.red)
                }
            }
            
            if movements.isEmpty {
                ContentUnavailableView("Sin cuotas", systemImage: "creditcard", description: Text("No hay cuotas programadas para este mes."))
            } else {
                // Agrupamos por Tarjeta para que se vea ordenado
                let grouped = Dictionary(grouping: movements, by: { $0.cardName })
                
                ForEach(grouped.keys.sorted(), id: \.self) { cardName in
                    Section(header: Text(cardName)) {
                        ForEach(grouped[cardName]!, id: \.expense.id) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.expense.title).font(.headline)
                                    Text("Compra: \(item.expense.date.formatted(date: .numeric, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(item.amount.formatted(.currency(code: "ARS"))).bold()
                                    Text("Cuota \(item.installmentNumber)/\(item.expense.installments)").font(.caption).foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(targetDate.formatted(.dateTime.month(.wide).year()))
    }
}
