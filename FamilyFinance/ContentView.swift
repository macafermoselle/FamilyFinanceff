import SwiftUI
import SwiftData
import CloudKit
import Charts

// MARK: - PUENTE SATELITAL PARA PAGOS (EL HACK DE SINCRONIZACIÓN)
func forcePushPaymentToCloud(costTitle: String, period: String?, payer: String?) {
    Task {
        print("🚀 Lanzando pago al satélite de iCloud para: \(costTitle)")
        let container = CKContainer.default()
        let predicate = NSPredicate(format: "CD_title == %@", costTitle)
        let query = CKQuery(recordType: "CD_FixedCost", predicate: predicate)
        
        // 1. Intento de Facu: Escribir en la base de datos compartida (la tuya)
        let sharedDB = container.sharedCloudDatabase
        if let (matchResults, _) = try? await sharedDB.records(matching: query),
           let firstMatch = matchResults.first,
           let record = try? firstMatch.1.get() {
            record["CD_lastPaidPeriod"] = period
            record["CD_paidByWho"] = payer
            try? await sharedDB.save(record)
            print("☁️✅ ¡Éxito! Pago de \(costTitle) inyectado en la Mochila Compartida.")
            return
        }
        
        // 2. Intento de Maca: Escribir en su propia base de datos (Privada)
        let privateDB = container.privateCloudDatabase
        if let (privResults, _) = try? await privateDB.records(matching: query),
           let firstPriv = privResults.first,
           let record = try? firstPriv.1.get() {
            record["CD_lastPaidPeriod"] = period
            record["CD_paidByWho"] = payer
            try? await privateDB.save(record)
            print("☁️✅ ¡Éxito! Pago de \(costTitle) inyectado en tu Mochila Privada.")
        } else {
            print("❌ No se encontró \(costTitle) en la nube para actualizar.")
        }
    }
}

// MARK: - 1. ESTRUCTURA PRINCIPAL
struct ContentView: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem { Label("Resumen", systemImage: "chart.pie.fill") }
                .tag(0)
            
            SavingsView()
                .tabItem { Label("Ahorros", systemImage: "dollarsign.circle.fill") }
                .tag(1)
            
            ExpensesListView()
                .tabItem { Label("Historial", systemImage: "list.bullet.rectangle.portrait") }
                .tag(2)
            
            FutureProjectionsView()
                .tabItem { Label("Futuro", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(3)
            
            SettingsView()
                .tabItem { Label("Configuración", systemImage: "gear") }
                .tag(4)
        }
    }
}

// MARK: - 2. DASHBOARD
struct DashboardView: View {
    @Binding var selectedTab: Int
        
    @Query var allExpenses: [Expense]
    @Query var allIncomes: [Income]
    @Query var budgets: [CategoryBudget]
    @Query var savings: [SavingGoal]
    @Query var allCards: [CreditCard]
    @Query var ledgers: [FamilyLedger]
    @Query var fixedCosts: [FixedCost]
    @Query(filter: #Predicate<Vacation> { $0.isActive == true }) var activeVacations: [Vacation]
        
    @EnvironmentObject var settings: FamilySettings
    @Environment(\.modelContext) private var modelContext
        
    @State private var hideBalance: Bool = false
    @State private var currentMonth = Date()
    @State private var showingAddExpense = false
    @State private var showingAddIncome = false
    
    // 🔒 PRIVACIDAD: Solo mis tarjetas
    var misTarjetas: [CreditCard] {
        allCards.filter { $0.ownerId == settings.deviceID }
    }
    
    var balance: Double {
        let totalIngresos = allIncomes.filter { $0.ownerId == settings.deviceID }.reduce(0) { $0 + $1.amount }
        let totalGastos = allExpenses.filter {
            $0.ownerId == settings.deviceID &&
            $0.paymentMethod != "Tarjeta de Crédito" &&
            $0.vacationName == nil
        }.reduce(0) { $0 + $1.amount }
        return totalIngresos - totalGastos
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    // 1. SALDO
                    VStack(spacing: 8) {
                        HStack {
                            Text("Saldo Disponible").font(.headline).foregroundStyle(.secondary)
                            Button { withAnimation(.snappy) { hideBalance.toggle() } } label: {
                                Image(systemName: hideBalance ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(.secondary).font(.caption).padding(6)
                                    .background(Color.gray.opacity(0.1)).clipShape(Circle())
                            }
                        }
                        if hideBalance {
                            Text("$ ••••••").font(.system(size: 46, weight: .black, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.5))
                        } else {
                            Text(balance.formatted(.currency(code: "ARS")))
                                .font(.system(size: 46, weight: .black, design: .rounded))
                                .foregroundStyle(balance >= 0 ? Color.primary : Color.red)
                        }
                    }.padding(.top)
                    
                    // 2. TARJETAS
                    if !misTarjetas.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Mis Tarjetas").font(.subheadline).bold().foregroundStyle(.secondary).padding(.horizontal)
                            ForEach(misTarjetas) { card in
                                TarjetaStatusRow(
                                    cardName: card.name,
                                    monto: montoPorTarjeta(nombre: card.name),
                                    pagada: estaPagada(nombreTarjeta: card.name),
                                    tieneDeudaHoy: allExpenses.filter({ $0.card?.name == card.name }).totalCreditDebt(for: currentMonth) > 0,
                                    mesActual: currentMonth.formatted(.dateTime.month(.wide)).capitalized,
                                    mesSiguiente: Calendar.current.date(byAdding: .month, value: 1, to: currentMonth)?.formatted(.dateTime.month(.wide)).capitalized ?? "",
                                    selectedTab: $selectedTab
                                )
                            }
                        }.padding(.horizontal)
                    }

                    // 3. INGRESOS Y GASTOS
                    HStack(spacing: 10) {
                        SummaryCard(icon: "arrow.up.circle.fill", color: .green, title: "Ingresos", amount: allIncomes.filter { $0.ownerId == settings.deviceID }.reduce(0){$0+$1.amount})
                            .onTapGesture { showingAddIncome = true }
                        SummaryCard(icon: "arrow.down.circle.fill", color: .red, title: "Gastos", amount: allExpenses.filter { $0.ownerId == settings.deviceID }.reduce(0){$0+$1.amount})
                            .onTapGesture { showingAddExpense = true }
                    }.padding(.horizontal)
                    
                    // 4. VENCIMIENTOS
                    BillTrackerView()
                    
                    // 5. GRÁFICO
                    let monthExpensesForChart = allExpenses.filter({ expense in
                        let esMio = expense.ownerId == settings.deviceID
                        let esEsteMes = Calendar.current.isDate(expense.date, equalTo: currentMonth, toGranularity: .month)
                        return esMio && esEsteMes && expense.vacationName == nil && expense.category != "Finanzas"
                    })

                    if !monthExpensesForChart.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Distribución").font(.headline).padding(.leading)
                            CategoryPieChart(expenses: monthExpensesForChart)
                        }
                        .padding(.horizontal)
                    }
                    Spacer()
                }
            }
            .navigationTitle("Resumen")
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear {
                Task { await CloudSharingManager.shared.manualRefresh(context: modelContext) }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 15) {
                        Button { showingAddIncome = true } label: { Image(systemName: "banknote").foregroundStyle(.green) }
                        Button { showingAddExpense = true } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) { AddExpenseView().environmentObject(settings) }
            .sheet(isPresented: $showingAddIncome) { AddIncomeView().environmentObject(settings) }
        }
    }
    
    func estaPagada(nombreTarjeta: String) -> Bool {
        let deuda = allExpenses.filter({ $0.card?.name == nombreTarjeta }).totalCreditDebt(for: currentMonth)
        if deuda <= 0 { return true }
        return allExpenses.contains {
            $0.category == "Finanzas" &&
            $0.title.localizedCaseInsensitiveContains("Pago Tarjeta \(nombreTarjeta)") &&
            Calendar.current.isDate($0.date, equalTo: currentMonth, toGranularity: .month)
        }
    }

    func montoPorTarjeta(nombre: String) -> Double {
        let fecha = estaPagada(nombreTarjeta: nombre) ? Calendar.current.date(byAdding: .month, value: 1, to: currentMonth)! : currentMonth
        return allExpenses.filter { $0.card?.name == nombre }.totalCreditDebt(for: fecha)
    }
}

// MARK: - 3. HISTORIAL DE GASTOS
struct ExpensesListView: View {
    @Query(sort: \Expense.date, order: .reverse) var expenses: [Expense]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: FamilySettings
    @Query var misCategorias: [ExpenseCategory]
    @State private var searchText = ""
    
    var filteredExpenses: [Expense] {
        let myOnlyExpenses = expenses.filter { $0.ownerId == settings.deviceID }
        if searchText.isEmpty { return myOnlyExpenses }
        else { return myOnlyExpenses.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.category.localizedCaseInsensitiveContains(searchText) } }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if filteredExpenses.isEmpty {
                    ContentUnavailableView("Sin resultados", systemImage: "magnifyingglass", description: Text("No se encontraron gastos."))
                }
                ForEach(filteredExpenses) { expense in
                    NavigationLink(destination: EditExpenseView(expense: expense)) {
                        HStack {
                            ZStack {
                                Circle().fill(settings.getColor(forUser: true).opacity(0.2)).frame(width: 40, height: 40)
                                Image(systemName: getCategoryIcon(for: expense.category)).foregroundStyle(settings.getColor(forUser: true)).font(.caption)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expense.title).font(.headline)
                                HStack {
                                    Text(expense.createdBy).font(.caption2).bold().foregroundStyle(settings.getColor(forUser: true))
                                    Text("• \(expense.category)").font(.caption)
                                }.foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(expense.amount.formatted(.currency(code: "ARS"))).bold()
                                Text(expense.date.formatted(.dateTime.day().month())).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet { modelContext.delete(filteredExpenses[index]) }
                    try? modelContext.save()
                }
            }
            .navigationTitle("Mis Gastos")
            .searchable(text: $searchText, prompt: "Buscar mis gastos...")
        }
    }
    
    private func getCategoryIcon(for categoryName: String) -> String {
        if let cat = misCategorias.first(where: { $0.name == categoryName }) { return cat.icon }
        if categoryName == "Hormiga" { return "ant.fill" }
        if categoryName == "Finanzas" { return "building.columns.fill" }
        return "tag.fill"
    }
}

// MARK: - 4. CONFIGURACIÓN
struct SettingsView: View {
    @Query var allCards: [CreditCard]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: FamilySettings
    
    var misTarjetas: [CreditCard] { allCards.filter { $0.ownerId == settings.deviceID } }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Finanzas y Control") {
                    NavigationLink(destination: FixedCostsView()) { Label("Vencimientos y Servicios", systemImage: "calendar.badge.clock").foregroundStyle(.red) }
                    NavigationLink(destination: FixedIncomesView()) { Label("Sueldos e Ingresos Fijos", systemImage: "repeat.circle.fill").foregroundStyle(.green) }
                    NavigationLink(destination: IncomesSettingsView()) { Label("Historial de Ingresos", systemImage: "banknote").foregroundStyle(.secondary) }
                    NavigationLink(destination: BudgetSettingsView()) { Label("Presupuestos", systemImage: "chart.bar.doc.horizontal").foregroundStyle(.blue) }
                    NavigationLink(destination: CategoriesSettingsView()) { Label("Categorías", systemImage: "tag.fill").foregroundStyle(.purple) }
                }
                Section("Modo Vacaciones ✈️") {
                    NavigationLink(destination: VacationSettingsView()) { Label("Mis Viajes", systemImage: "airplane").foregroundStyle(.orange) }
                }
                Section("Mis Tarjetas") {
                    ForEach(misTarjetas) { card in
                        NavigationLink(destination: EditCardView(card: card)) {
                            HStack { Circle().fill(Color(hex: card.colorHex)).frame(width: 12); Text(card.name) }
                        }
                    }.onDelete { idx in idx.forEach { modelContext.delete(misTarjetas[$0]) } }
                    NavigationLink(destination: AddCardView()) { Label("Agregar Tarjeta", systemImage: "plus") }
                }
                Section("Familia & Sincronización") {
                    NavigationLink(destination: FamilySettingsView()) { Label("Configuración Familiar", systemImage: "person.2.circle").foregroundStyle(.purple) }
                    NavigationLink(destination: CloudKitSettingsView()) { Label("Sincronización (iCloud)", systemImage: "icloud").foregroundStyle(.blue) }
                }
            }
            .navigationTitle("Configuración")
        }
    }
}

// MARK: - VISTAS DE SOPORTE

struct EditExpenseView: View {
    @Bindable var expense: Expense
    @Query(sort: \ExpenseCategory.name) var categories: [ExpenseCategory]
    @Query var allCards: [CreditCard]
    @EnvironmentObject var settings: FamilySettings
    @Environment(\.dismiss) var dismiss
    
    var misTarjetas: [CreditCard] { allCards.filter { $0.ownerId == settings.deviceID } }
    
    var body: some View {
        Form {
            Section("Detalle") {
                TextField("Concepto", text: $expense.title)
                TextField("Monto", value: $expense.amount, format: .currency(code: "ARS")).keyboardType(.decimalPad)
                DatePicker("Fecha", selection: $expense.date, displayedComponents: .date)
            }
            Section("Clasificación") {
                Picker("Categoría", selection: $expense.category) {
                    Text("Varios").tag("Varios")
                    ForEach(categories) { Text($0.name).tag($0.name) }
                }
                Toggle("🐜 Gasto Hormiga", isOn: $expense.isHormiga)
            }
            if !expense.isHormiga {
                Section("Pago") {
                    Picker("Medio", selection: $expense.paymentMethod) {
                        Text("Efectivo / Débito").tag("Efectivo / Débito")
                        Text("Tarjeta de Crédito").tag("Tarjeta de Crédito")
                    }
                    if expense.paymentMethod == "Tarjeta de Crédito" {
                        Picker("Tarjeta", selection: $expense.card) {
                            Text("Seleccionar...").tag(nil as CreditCard?)
                            ForEach(misTarjetas) { Text($0.name).tag($0 as CreditCard?) }
                        }
                    }
                }
            }
        }.toolbar { Button("Listo") { dismiss() } }.navigationTitle("Editar Gasto")
    }
}



// MARK: - COMPONENTES REUTILIZABLES

struct SummaryCard: View {
    let icon: String, color: Color, title: String, amount: Double
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.title2)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(amount.formatted(.currency(code: "ARS"))).font(.subheadline).bold()
        }.frame(maxWidth: .infinity).padding().background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(15).contentShape(Rectangle())
    }
}

struct BillTrackerView: View {
    @Query(sort: \FixedCost.dueDay) var fixedCosts: [FixedCost]
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var settings: FamilySettings
    @State private var costToPay: FixedCost?
    @State private var costToUnpay: FixedCost?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Vencimientos").font(.headline)
                Spacer()
                NavigationLink(destination: FixedCostsView()) { Text("Gestionar").font(.caption).bold().foregroundStyle(.blue) }
            }.padding(.horizontal)
            if fixedCosts.isEmpty {
                Text("No hay datos sincronizados.").font(.caption).padding().frame(maxWidth: .infinity).background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(12).padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(fixedCosts) { cost in
                            BillCard(cost: cost) { if cost.isPaidThisMonth() { costToUnpay = cost } else { costToPay = cost } }
                        }
                    }.padding(.horizontal)
                }
            }
        }
        .sheet(item: $costToPay) { cost in AddExpenseView(preFilledCost: cost).environmentObject(settings) }
        .alert(item: $costToUnpay) { cost in
            Alert(title: Text("¿Anular pago?"), message: Text("Se borrará el gasto del historial."), primaryButton: .destructive(Text("Borrar")) { deleteLinkedExpense(for: cost) }, secondaryButton: .cancel())
        }
    }
    
    func deleteLinkedExpense(for cost: FixedCost) {
            let titleToFind = cost.title
            let descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.title == titleToFind })
            if let foundExpenses = try? modelContext.fetch(descriptor) {
                let calendar = Calendar.current
                if let expenseToDelete = foundExpenses.first(where: { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }) { modelContext.delete(expenseToDelete) }
            }
            withAnimation { cost.markAsUnpaid() }
            
            // 👇 EL HACK INVERSO: Anulamos el pago en la nube agregando el CloudSharingManager.shared
            CloudSharingManager.shared.forcePushPaymentToCloud(costTitle: cost.title, period: nil, payer: nil)
            
            try? modelContext.save()
        }
}

struct BillCard: View {
    let cost: FixedCost; let action: () -> Void
    var isPaid: Bool { cost.isPaidThisMonth() }
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: cost.icon).foregroundStyle(isPaid ? .green : .orange).font(.title3)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: isPaid ? "checkmark.circle.fill" : "circle").foregroundStyle(isPaid ? .green : .secondary)
                        if isPaid, let payer = cost.paidByWho { Text(payer).font(.system(size: 9, weight: .bold)).foregroundStyle(.green) }
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(cost.title).font(.subheadline).bold().lineLimit(1).foregroundStyle(.primary).strikethrough(isPaid)
                    Text(cost.amount.formatted(.currency(code: "ARS"))).font(.caption).foregroundStyle(.secondary)
                }
            }.padding(12).frame(width: 145, height: 110).background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(isPaid ? Color.green.opacity(0.3) : .clear, lineWidth: 2))
        }.buttonStyle(.plain)
    }
}

struct TarjetaStatusRow: View {
    let cardName: String, monto: Double, pagada: Bool, tieneDeudaHoy: Bool, mesActual: String, mesSiguiente: String
    @Binding var selectedTab: Int
    var body: some View {
        HStack {
            Image(systemName: "creditcard.fill").foregroundStyle(pagada ? Color.blue : Color.orange)
            VStack(alignment: .leading) { Text(cardName).bold(); Text(pagada ? "Próximo: \(mesSiguiente)" : "Vence: \(mesActual)").font(.caption2).foregroundStyle(.secondary) }
            Spacer()
            Text(monto.formatted(.currency(code: "ARS"))).foregroundStyle(pagada ? Color.primary : Color.red).bold()
        }.padding().background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(12)
    }
}

struct HormigaCard: View {
    let totalHormiga: Double
    var body: some View {
        HStack {
            Image(systemName: "ant.fill").foregroundStyle(.orange)
            VStack(alignment: .leading) { Text("Gastos Hormiga").font(.subheadline).bold(); Text("Total este mes").font(.caption2).foregroundStyle(.secondary) }
            Spacer()
            Text(totalHormiga.formatted(.currency(code: "ARS"))).bold()
        }.padding().background(Color.orange.opacity(0.1)).cornerRadius(12)
    }
}



struct IncomesSettingsView: View {
    @Query(sort: \Income.date, order: .reverse) var incomes: [Income]
    @EnvironmentObject var settings: FamilySettings
    var misIngresos: [Income] { incomes.filter { $0.ownerId == settings.deviceID } }
    var body: some View {
        List { ForEach(misIngresos) { inc in HStack { VStack(alignment: .leading) { Text(inc.title).bold(); Text(inc.category).font(.caption) }; Spacer(); Text(inc.amount.formatted(.currency(code: "ARS"))).bold() } } }.navigationTitle("Historial Ingresos")
    }
}

struct VacationSettingsView: View {
    @Query var vacations: [Vacation]; @Environment(\.modelContext) var modelContext; @State private var newName = ""
    var body: some View {
        List {
            HStack { TextField("Nuevo Viaje", text: $newName); Button("Crear") { modelContext.insert(Vacation(name: newName)); newName = "" }.disabled(newName.isEmpty) }
            ForEach(vacations) { v in HStack { NavigationLink(destination: VacationDetailView(vacation: v)) { VStack(alignment: .leading) { Text(v.name).bold(); Text(v.isActive ? "Activo" : "Terminado").font(.caption).foregroundStyle(v.isActive ? .green : .gray) } }; if v.isActive { Button("Terminar") { withAnimation { v.isActive = false } }.buttonStyle(.borderless).font(.caption).tint(.red) } } }.onDelete { idx in idx.forEach { modelContext.delete(vacations[$0]) } }
        }.navigationTitle("Mis Viajes")
    }
}

struct VacationDetailView: View {
    let vacation: Vacation; @Query var allExpenses: [Expense]
    var expenses: [Expense] { allExpenses.filter { $0.vacationName == vacation.name } }
    var body: some View { List { Section("Total") { Text(expenses.reduce(0){$0+$1.amount}.formatted(.currency(code: "ARS"))).font(.title).bold().foregroundStyle(.orange) }; ForEach(expenses) { e in HStack { Text(e.title); Spacer(); Text(e.amount.formatted(.currency(code: "ARS"))) } } }.navigationTitle(vacation.name) }
}

struct EditCardView: View {
    @Bindable var card: CreditCard; let colors = ["#0000FF", "#FF0000", "#008000", "#FFA500", "#800080", "#000000"]
    var body: some View {
        Form {
            TextField("Nombre", text: $card.name); TextField("Banco", text: $card.bankName)
            ScrollView(.horizontal) { HStack { ForEach(colors, id: \.self) { hex in Circle().fill(Color(hex: hex)).frame(width: 30).overlay(Circle().stroke(Color.primary, lineWidth: card.colorHex == hex ? 2 : 0)).onTapGesture { card.colorHex = hex } } } }
            Picker("Cierre", selection: $card.closingDay) { ForEach(1...31, id: \.self) { Text("\($0)").tag($0) } }
            Picker("Vencimiento", selection: $card.dueDay) { ForEach(1...31, id: \.self) { Text("\($0)").tag($0) } }
        }.navigationTitle("Editar Tarjeta")
    }
}

struct AddCardView: View {
    @Environment(\.modelContext) var modelContext; @Environment(\.dismiss) var dismiss; @EnvironmentObject var settings: FamilySettings
    @State private var name = ""; @State private var bank = ""; @State private var color = "#0000FF"; @State private var closing = 24; @State private var due = 5
    let colors = ["#0000FF", "#FF0000", "#008000", "#FFA500", "#800080", "#000000"]
    var body: some View {
        Form {
            TextField("Nombre", text: $name); TextField("Banco", text: $bank)
            ScrollView(.horizontal) { HStack { ForEach(colors, id: \.self) { hex in Circle().fill(Color(hex: hex)).frame(width: 30).overlay(Circle().stroke(Color.primary, lineWidth: color == hex ? 2 : 0)).onTapGesture { color = hex } } } }
            Picker("Cierre", selection: $closing) { ForEach(1...31, id: \.self) { Text("\($0)").tag($0) } }
            Picker("Vencimiento", selection: $due) { ForEach(1...31, id: \.self) { Text("\($0)").tag($0) } }
            Button("Guardar") {
                let newCard = CreditCard(name: name, bankName: bank, last4Digits: "", closingDay: closing, dueDay: due, colorHex: color)
                newCard.ownerId = settings.deviceID
                modelContext.insert(newCard); try? modelContext.save(); dismiss()
            }.disabled(name.isEmpty)
        }.navigationTitle("Nueva Tarjeta")
    }
}

extension Color {
    init(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.hasPrefix("#") { clean.removeFirst() }
        if clean.count != 6 { self.init(.gray); return }
        var rgb: UInt64 = 0; Scanner(string: clean).scanHexInt64(&rgb)
        self.init(red: Double((rgb & 0xFF0000) >> 16)/255, green: Double((rgb & 0x00FF00) >> 8)/255, blue: Double(rgb & 0x0000FF)/255)
    }
}
