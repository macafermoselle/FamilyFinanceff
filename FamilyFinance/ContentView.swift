import SwiftUI
import SwiftData
import Charts
import UserNotifications

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Resumen", systemImage: "chart.pie.fill") }
            SavingsView()
                .tabItem { Label("Ahorros", systemImage: "dollarsign.circle.fill") }
            
            // Asumiendo que tienes FutureProjectionsView.swift en tu carpeta
            FutureProjectionsView()
               .tabItem { Label("Futuro", systemImage: "calendar.badge.clock") }
            
            ExpensesListView()
                .tabItem { Label("Historial", systemImage: "list.bullet.rectangle.portrait") }
            SettingsView()
                .tabItem { Label("Configuración", systemImage: "gear") }
        }
    }
}

// MARK: - 1. DASHBOARD
struct DashboardView: View {
    @Query var expenses: [Expense]
    @Query var incomes: [Income]
    @Query var budgets: [CategoryBudget]
    @Query var savings: [SavingGoal]
    
    @State private var showingAddExpense = false
    @State private var showingAddIncome = false
    
    let currentMonth = Date()
    
    // --- CÁLCULOS ---
    var incomeTotal: Double {
        incomes.filter { Calendar.current.isDate($0.date, equalTo: currentMonth, toGranularity: .month) }.reduce(0) { $0 + $1.amount }
    }
    var expensesTotal: Double {
        let cash = expenses.filter { $0.paymentMethod != "Tarjeta de Crédito" && Calendar.current.isDate($0.date, equalTo: currentMonth, toGranularity: .month) }.reduce(0) { $0 + $1.amount }
        var credit = 0.0
        let creditExpenses = expenses.filter { $0.paymentMethod == "Tarjeta de Crédito" }
        for expense in creditExpenses {
            let closingDay = expense.card?.closingDay ?? 24; var startPaymentDate = expense.date; let dayOfPurchase = Calendar.current.component(.day, from: expense.date)
            if dayOfPurchase > closingDay { if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: expense.date) { startPaymentDate = nextMonth } }
            if let endPaymentDate = Calendar.current.date(byAdding: .month, value: expense.installments - 1, to: startPaymentDate) {
                if Calendar.current.compare(currentMonth, to: startPaymentDate, toGranularity: .month) != .orderedAscending && Calendar.current.compare(currentMonth, to: endPaymentDate, toGranularity: .month) != .orderedDescending {
                    credit += (expense.amount / Double(expense.installments))
                }
            }
        }
        return cash + credit
    }
    var savingsTotal: Double { savings.reduce(0) { $0 + $1.currentAmount } }
    var balance: Double { incomeTotal - expensesTotal - savingsTotal }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // 1. SALDO
                    VStack(spacing: 5) {
                        Text("Saldo Disponible").font(.headline).foregroundStyle(.secondary)
                        Text(balance.formatted(.currency(code: "ARS")))
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .foregroundStyle(balance >= 0 ? Color.primary : Color.red)
                    }
                    .padding(.top)
                    
                    // 2. TARJETAS RESUMEN
                    HStack(spacing: 10) {
                        SummaryCard(icon: "arrow.up.circle.fill", color: .green, title: "Ingresos", amount: incomeTotal).onTapGesture { showingAddIncome = true }
                        SummaryCard(icon: "arrow.down.circle.fill", color: .red, title: "Gastos", amount: expensesTotal)
                        SummaryCard(icon: "dollarsign.circle.fill", color: .blue, title: "Ahorros", amount: savingsTotal)
                    }
                    .padding(.horizontal)
                    
                    // 3. BILL TRACKER (VENCIMIENTOS)
                    BillTrackerView()
                    
                    // 4. GRÁFICO DE TORTA
                    if expensesTotal > 0 {
                        let currentMonthExpenses = expenses.filter { Calendar.current.isDate($0.date, equalTo: currentMonth, toGranularity: .month) }
                        if !currentMonthExpenses.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Distribución de Gastos").font(.headline).padding(.leading)
                                CategoryPieChart(expenses: currentMonthExpenses)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // 5. PRESUPUESTOS
                    if !budgets.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Mis Presupuestos").font(.headline).padding(.horizontal)
                            ForEach(budgets) { budget in BudgetProgressRow(budget: budget, allExpenses: expenses) }
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Resumen")
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 15) {
                        Button(action: { showingAddIncome = true }) { Image(systemName: "banknote").foregroundStyle(.green).font(.system(size: 20)) }
                        Button(action: { showingAddExpense = true }) { Image(systemName: "plus.circle.fill").font(.system(size: 26)) }
                    }
                }
            }
            // AddExpenseView y AddIncomeView deben existir en tus archivos
            .sheet(isPresented: $showingAddExpense) { AddExpenseView() }
            .sheet(isPresented: $showingAddIncome) { AddIncomeView() }
        }
    }
}

// MARK: - BILL TRACKER (Componente Visual)
struct BillTrackerView: View {
    @Query var fixedCosts: [FixedCost]
    @Query var expenses: [Expense]
    @State private var costToPay: FixedCost?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Vencimientos del Mes")
                .font(.headline)
                .padding(.horizontal)
            
            if fixedCosts.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Configura tus costos fijos en Configuración.").font(.caption)
                }
                .padding().frame(maxWidth: .infinity).background(Color.white).cornerRadius(12).padding(.horizontal).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(fixedCosts) { cost in
                            BillCard(cost: cost, isPaid: checkPayment(for: cost)) {
                                costToPay = cost
                            }
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 5)
                }
            }
        }
        .sheet(item: $costToPay) { cost in
            AddExpenseView(preFilledCost: cost)
        }
    }
    
    func checkPayment(for cost: FixedCost) -> Bool {
        let currentMonth = Date()
        return expenses.contains { expense in
            expense.title.localizedCaseInsensitiveContains(cost.title) &&
            Calendar.current.isDate(expense.date, equalTo: currentMonth, toGranularity: .month)
        }
    }
}

struct BillCard: View {
    let cost: FixedCost; let isPaid: Bool; let action: () -> Void
    var body: some View {
        Button(action: { if !isPaid { action() } }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: cost.icon).foregroundStyle(isPaid ? .green : .orange).font(.title3)
                    Spacer()
                    Image(systemName: isPaid ? "checkmark.circle.fill" : "circle").foregroundStyle(isPaid ? .green : .secondary)
                }
                Text(cost.title).font(.subheadline).bold().lineLimit(1).foregroundStyle(.primary)
                Text(cost.amount.formatted(.currency(code: "ARS"))).font(.caption).foregroundStyle(.secondary)
            }
            .padding(12).frame(width: 140, height: 100).background(Color.white).cornerRadius(12).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isPaid ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2))
        }.disabled(isPaid)
    }
}

// MARK: - 2. HISTORIAL (OPTIMIZADO)
struct ExpensesListView: View {
    @Query(sort: \Expense.date, order: .reverse) var expenses: [Expense]
    @Query(sort: \ExpenseCategory.name) var categories: [ExpenseCategory]
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    
    var filteredExpenses: [Expense] {
        var result = expenses
        if let category = selectedCategory { result = result.filter { $0.category == category } }
        if !searchText.isEmpty { result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) } }
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // FILTROS
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterChip(title: "Todos", isSelected: selectedCategory == nil) { withAnimation { selectedCategory = nil } }
                        if categories.isEmpty {
                            ForEach(["Supermercado", "Comida", "Transporte", "Servicios", "Varios"], id: \.self) { cat in
                                FilterChip(title: cat, isSelected: selectedCategory == cat) { withAnimation { if selectedCategory == cat { selectedCategory = nil } else { selectedCategory = cat } } }
                            }
                        } else {
                            ForEach(categories) { cat in
                                FilterChip(title: cat.name, isSelected: selectedCategory == cat.name) { withAnimation { if selectedCategory == cat.name { selectedCategory = nil } else { selectedCategory = cat.name } } }
                            }
                        }
                    }.padding(.horizontal).padding(.vertical, 10)
                }.background(Color(uiColor: .systemGroupedBackground))
                
                // LISTA OPTIMIZADA (Usa Subvista ExpenseRow para evitar el error del compilador)
                List {
                    if filteredExpenses.isEmpty {
                        ContentUnavailableView("No encontrado", systemImage: "magnifyingglass", description: Text("Intenta con otro término."))
                    }
                    ForEach(filteredExpenses) { expense in
                        ExpenseRow(expense: expense, categories: categories)
                    }
                    .onDelete(perform: deleteExpenses)
                }
            }
            .navigationTitle("Historial")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { if !expenses.isEmpty { ShareLink(item: generateCSV()) { Label("Exportar", systemImage: "square.and.arrow.up") } } }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
        }
    }
    
    func generateCSV() -> URL {
        var csvString = "Fecha,Concepto,Categoria,Monto,Metodo Pago,Cuotas\n"
        for expense in filteredExpenses {
            let date = expense.date.formatted(date: .numeric, time: .omitted); let title = expense.title.replacingOccurrences(of: ",", with: " "); let amount = String(format: "%.2f", expense.amount); let row = "\(date),\(title),\(expense.category),\(amount),\(expense.paymentMethod),\(expense.installments)\n"; csvString.append(row)
        }
        let tempUrl = URL.documentsDirectory.appending(path: "Gastos_FamilyFinance.csv"); try? csvString.write(to: tempUrl, atomically: true, encoding: .utf8); return tempUrl
    }
    
    private func deleteExpenses(offsets: IndexSet) { withAnimation { for index in offsets { let expenseToDelete = filteredExpenses[index]; modelContext.delete(expenseToDelete) } } }
}

// SUBVISTA DE GASTO (Para arreglar el error de complejidad del compilador)
struct ExpenseRow: View {
    let expense: Expense
    let categories: [ExpenseCategory]
    
    var body: some View {
        NavigationLink(destination: EditExpenseView(expense: expense)) {
            HStack {
                Image(systemName: iconForCategory(expense.category))
                    .padding(8).background(Color.blue.opacity(0.1)).clipShape(Circle())
                VStack(alignment: .leading) {
                    Text(expense.title).font(.headline)
                    HStack {
                        Text(expense.date.formatted(.dateTime.day().month()))
                        if expense.paymentMethod == "Tarjeta de Crédito" { Text("• \(expense.installments) cuotas").foregroundStyle(.purple).font(.caption) }
                    }.foregroundStyle(.secondary)
                }
                Spacer()
                Text(expense.amount.formatted(.currency(code: "ARS"))).bold().foregroundStyle(expense.amount > 100000 ? .red : .primary)
            }
        }
    }
    
    func iconForCategory(_ catName: String) -> String {
        if let match = categories.first(where: { $0.name == catName }) { return match.icon }; return "bag.fill"
    }
}


// MARK: - 3. CONFIGURACIÓN
struct SettingsView: View {
    @Query var cards: [CreditCard]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false; @State private var reminderTime = Date()
    
    var body: some View {
        NavigationStack {
            List {
                Section("Finanzas") {
                    // ASUMIENDO QUE TIENES ESTOS ARCHIVOS, SI NO, USA LOS DE ABAJO
                    NavigationLink(destination: FixedIncomesView()) { Label { Text("Sueldos e Ingresos Fijos") } icon: { Image(systemName: "repeat.circle.fill").foregroundStyle(.green) } }
                    NavigationLink(destination: IncomesSettingsView()) { Label { Text("Historial de Ingresos") } icon: { Image(systemName: "banknote").foregroundStyle(.secondary) } }
                    NavigationLink(destination: BudgetSettingsView()) { Label { Text("Presupuestos por Categoría") } icon: { Image(systemName: "chart.bar.doc.horizontal").foregroundStyle(.blue) } }
                    NavigationLink(destination: CategoriesSettingsView()) { Label { Text("Gestionar Categorías") } icon: { Image(systemName: "tag.fill").foregroundStyle(.purple) } }
                }
                Section("Mis Tarjetas") {
                    if cards.isEmpty { Text("No tienes tarjetas guardadas").foregroundStyle(.secondary).italic() }
                    ForEach(cards) { card in NavigationLink(destination: EditCardView(card: card)) { HStack { Circle().fill(Color(hex: card.colorHex)).frame(width: 12); Text(card.name) } } }.onDelete { idx in for i in idx { modelContext.delete(cards[i]) } }
                    NavigationLink(destination: AddCardView()) { Label("Agregar nueva tarjeta", systemImage: "plus") }
                }
                Section("Gestión Mensual") {
                    NavigationLink(destination: FixedCostsView()) { Label { Text("Costos Fijos y Servicios") } icon: { Image(systemName: "calendar.badge.clock").foregroundStyle(.orange) } }
                }
                Section("Recordatorios") {
                    Toggle("Recordarme cargar gastos", isOn: $notificationsEnabled).onChange(of: notificationsEnabled) { oldValue, newValue in if newValue { NotificationManager.shared.requestPermission(); schedule() } else { NotificationManager.shared.cancelNotifications() } }
                    if notificationsEnabled { DatePicker("Hora del aviso", selection: $reminderTime, displayedComponents: .hourAndMinute).onChange(of: reminderTime) { _, _ in schedule() } }
                }
            }.navigationTitle("Configuración")
        }
    }
    func schedule() { let calendar = Calendar.current; let hour = calendar.component(.hour, from: reminderTime); let minute = calendar.component(.minute, from: reminderTime); NotificationManager.shared.scheduleDailyReminder(at: hour, minute: minute) }
}

// MARK: - HELPERS (Chips y Tarjetas)
struct FilterChip: View {
    let title: String; let isSelected: Bool; let action: () -> Void
    var body: some View { Button(action: action) { Text(title).font(.subheadline).fontWeight(isSelected ? .bold : .regular).padding(.horizontal, 16).padding(.vertical, 8).background(isSelected ? Color.blue : Color.white).foregroundStyle(isSelected ? .white : .primary).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.3), lineWidth: isSelected ? 0 : 1)) } }
}

struct SummaryCard: View {
    let icon: String; let color: Color; let title: String; let amount: Double
    var body: some View { VStack(alignment: .leading) { HStack { Image(systemName: icon).foregroundStyle(color); Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8) }; Text(amount.formatted(.currency(code: "ARS").precision(.fractionLength(0)))).font(.subheadline).bold().minimumScaleFactor(0.8).lineLimit(1) }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color(uiColor: .systemGray6)).cornerRadius(12) }
}

struct BudgetProgressRow: View {
    let budget: CategoryBudget; let allExpenses: [Expense]
    var spentAmount: Double { let currentMonth = Date(); return allExpenses.filter { expense in expense.category == budget.category && Calendar.current.isDate(expense.date, equalTo: currentMonth, toGranularity: .month) }.reduce(0) { total, expense in if expense.paymentMethod == "Tarjeta de Crédito" { return total + (expense.amount / Double(expense.installments)) } else { return total + expense.amount } } }
    var progress: Double { guard budget.limit > 0 else { return 0 }; return spentAmount / budget.limit }
    var color: Color { if progress > 1.0 { return .red }; if progress > 0.8 { return .orange }; return .green }
    var body: some View { VStack(alignment: .leading, spacing: 5) { HStack { Text(budget.category).font(.subheadline).bold(); Spacer(); Text("\(spentAmount.formatted(.currency(code: "ARS").precision(.fractionLength(0)))) / \(budget.limit.formatted(.currency(code: "ARS").precision(.fractionLength(0))))").font(.caption).foregroundStyle(.secondary) }; GeometryReader { geo in ZStack(alignment: .leading) { RoundedRectangle(cornerRadius: 5).fill(Color.gray.opacity(0.2)).frame(height: 10); RoundedRectangle(cornerRadius: 5).fill(color).frame(width: min(CGFloat(progress) * geo.size.width, geo.size.width), height: 10) } }.frame(height: 10); if progress > 1.0 { Text("Te pasaste por \((spentAmount - budget.limit).formatted(.currency(code: "ARS"))) 😱").font(.caption2).foregroundStyle(.red).bold() } }.padding().background(Color.white).cornerRadius(12).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1).padding(.horizontal) }
}

extension Color { init(hex: String) { var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(); if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }; if cleanHex.count != 6 { self.init(.gray); return }; var rgbValue: UInt64 = 0; Scanner(string: cleanHex).scanHexInt64(&rgbValue); let r = (rgbValue & 0xFF0000) >> 16; let g = (rgbValue & 0x00FF00) >> 8; let b = rgbValue & 0x0000FF; self.init(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0) } }

// MARK: - VISTAS RESTAURADAS (Para que compile si no las tienes en carpetas)
// Si ya las tienes en carpetas y te da error de "Redeclaración", bórralas de aquí.

struct EditExpenseView: View { @Bindable var expense: Expense; @Environment(\.modelContext) private var modelContext; @Environment(\.dismiss) private var dismiss; @Query(sort: \ExpenseCategory.name) var availableCategories: [ExpenseCategory]; var body: some View { Form { Section("Detalle") { TextField("Concepto", text: $expense.title); TextField("Monto", value: $expense.amount, format: .currency(code: "ARS")).keyboardType(.decimalPad); Picker("Categoría", selection: $expense.category) { if availableCategories.isEmpty { Text("Varios").tag("Varios") } else { ForEach(availableCategories) { cat in Text(cat.name).tag(cat.name) } } }; DatePicker("Fecha", selection: $expense.date, displayedComponents: .date) }; if expense.paymentMethod == "Tarjeta de Crédito" { Section("Cuotas") { Stepper("Cuotas: \(expense.installments)", value: $expense.installments, in: 1...24) } }; Button(role: .destructive) { modelContext.delete(expense); dismiss() } label: { Text("Eliminar Gasto") } }.navigationTitle("Editar Gasto") } }

struct IncomesSettingsView: View { @Query(sort: \Income.date, order: .reverse) var incomes: [Income]; @Environment(\.modelContext) private var modelContext; var body: some View { List { if incomes.isEmpty { ContentUnavailableView("Sin ingresos", systemImage: "banknote", description: Text("No has registrado ingresos aún.")) } ; ForEach(incomes) { income in NavigationLink(destination: EditIncomeView(income: income)) { HStack { VStack(alignment: .leading) { Text(income.title).font(.headline); Text(income.date.formatted(date: .long, time: .omitted)).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(income.amount.formatted(.currency(code: "ARS"))).foregroundStyle(.green) } } }.onDelete { idx in for i in idx { modelContext.delete(incomes[i]) } } }.navigationTitle("Historial de Ingresos").toolbar { EditButton() } } }
struct EditIncomeView: View { @Bindable var income: Income; @Environment(\.modelContext) private var modelContext; @Environment(\.dismiss) private var dismiss; var body: some View { Form { Section { TextField("Concepto", text: $income.title); TextField("Monto", value: $income.amount, format: .currency(code: "ARS")).keyboardType(.decimalPad); DatePicker("Fecha", selection: $income.date, displayedComponents: .date) }; Button(role: .destructive) { modelContext.delete(income); dismiss() } label: { Text("Eliminar Ingreso") } }.navigationTitle("Editar Ingreso") } }


struct EditCardView: View { @Bindable var card: CreditCard; let colors = ["#0000FF", "#FF0000", "#008000", "#FFA500", "#800080", "#000000"]; var body: some View { Form { Section("Identificación") { TextField("Nombre", text: $card.name); TextField("Banco", text: $card.bankName); Picker("Color", selection: $card.colorHex) { ForEach(colors, id: \.self) { color in HStack { Circle().fill(Color(hex: color)).frame(width: 20); Text("Color") }.tag(color) } } }; Section("Fechas") { Picker("Día de Cierre", selection: $card.closingDay) { ForEach(1...31, id: \.self) { Text("\($0)").tag($0) } }; Picker("Día de Pago", selection: $card.dueDay) { ForEach(1...31, id: \.self) { Text("\($0)").tag($0) } } } }.navigationTitle("Editar Tarjeta") } }
struct AddCardView: View { @Environment(\.modelContext) private var modelContext; @Environment(\.dismiss) private var dismiss; @State private var name = ""; @State private var bank = ""; @State private var closingDay = 24; @State private var dueDay = 5; @State private var colorHex = "#0000FF"; let colors = ["#0000FF", "#FF0000", "#008000", "#FFA500", "#800080", "#000000"]; var body: some View { Form { Section("Identificación") { TextField("Nombre", text: $name); TextField("Banco", text: $bank); Picker("Color", selection: $colorHex) { ForEach(colors, id: \.self) { color in HStack { Circle().fill(Color(hex: color)).frame(width: 20); Text("Color") }.tag(color) } } }; Section("Fechas") { Picker("Día de Cierre", selection: $closingDay) { ForEach(1...31, id: \.self) { Text("\($0)").tag($0) } }; Picker("Día de Pago", selection: $dueDay) { ForEach(1...31, id: \.self) { Text("\($0)").tag($0) } } }; Button("Guardar") { let new = CreditCard(name: name, bankName: bank, last4Digits: "", closingDay: closingDay, dueDay: dueDay, colorHex: colorHex); modelContext.insert(new); dismiss() }.disabled(name.isEmpty) }.navigationTitle("Nueva Tarjeta") } }

#Preview {
    ContentView()
        .modelContainer(for: [Expense.self, CreditCard.self, FixedCost.self, Income.self, FixedIncome.self, CategoryBudget.self, SavingGoal.self, ExpenseCategory.self], inMemory: true)
}

struct AddSavingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var targetString = ""
    @State private var initialString = ""
    @State private var currency = "ARS"
    let currencies = ["ARS", "USD"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Detalle") {
                    TextField("Nombre", text: $name)
                    Picker("Moneda", selection: $currency) {
                        ForEach(currencies, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("Montos") {
                    TextField("Monto Inicial", text: $initialString).keyboardType(.decimalPad)
                    TextField("Meta a alcanzar", text: $targetString).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Nueva Meta")
            .toolbar {
                Button("Guardar") {
                    let cleanTarget = targetString.replacingOccurrences(of: ",", with: ".")
                    let cleanInitial = initialString.replacingOccurrences(of: ",", with: ".")
                    let newGoal = SavingGoal(
                        name: name,
                        targetAmount: Double(cleanTarget) ?? 0.0,
                        currentAmount: Double(cleanInitial) ?? 0.0,
                        currency: currency,
                        icon: "lock.square.fill"
                    )
                    modelContext.insert(newGoal)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
    }
}

