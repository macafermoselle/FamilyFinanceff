import SwiftUI
import SwiftData

// MARK: - VISTA PRINCIPAL (LISTA + CHECKBOX)

struct FixedCostsView: View {
    @Query(sort: \FixedCost.dueDay) var fixedCosts: [FixedCost]
    @Query var ledgers: [FamilyLedger]
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: FamilySettings
    @StateObject private var shareManager = CloudSharingManager.shared
    
    @State private var showingAddCost = false
    @State private var isSyncingManually = false
    
    // Variables para controlar qué pantalla se abre
    @State private var costToPay: FixedCost?
    @State private var costToUnpay: FixedCost?
    @State private var costToEdit: FixedCost?
    
    var totalAmount: Double { fixedCosts.reduce(0) { $0 + $1.amount } }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // PANEL RESUMEN
                VStack(spacing: 8) {
                    Text("Total Compromiso Mensual").font(.subheadline).foregroundStyle(.secondary)
                    Text(totalAmount.formatted(.currency(code: "ARS")))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 12) {
                        Text("\(fixedCosts.count) servicios")
                            .font(.caption).padding(6).background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue).clipShape(Capsule())
                        
                        Text("\(fixedCosts.filter({$0.isPaidThisMonth()}).count) pagados")
                            .font(.caption).padding(6).background(Color.green.opacity(0.1))
                            .foregroundStyle(.green).clipShape(Capsule())
                    }
                    
                    // 👇 INDICADOR DE MOCHILA (Visualizamos el ID para confirmar unión)
                    if let ledger = ledgers.first {
                        Text("Mochila ID: \(ledger.id.uuidString.prefix(8))")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 25)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                
                List {
                    Section("Vencimientos del Mes") {
                        if fixedCosts.isEmpty {
                            ContentUnavailableView("Sin servicios", systemImage: "calendar.badge.exclamationmark", description: Text("Agregá tus facturas del mes aquí."))
                        }
                        
                        ForEach(fixedCosts) { cost in
                            HStack {
                                // BOTÓN IZQUIERDO: EDITAR
                                Button(action: { costToEdit = cost }) {
                                    HStack {
                                        VStack {
                                            Image(systemName: cost.icon)
                                                .foregroundStyle(cost.isPaidThisMonth() ? .green : .orange)
                                                .frame(width: 30).font(.title3)
                                            Text("Día \(cost.dueDay)").font(.caption2).bold().foregroundStyle(.secondary)
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text(cost.title).font(.headline)
                                                .strikethrough(cost.isPaidThisMonth())
                                                .foregroundStyle(cost.isPaidThisMonth() ? .secondary : .primary)
                                            Text(cost.amount.formatted(.currency(code: "ARS")))
                                                .font(.caption).bold().foregroundStyle(.secondary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                // BOTÓN DERECHO: PAGAR
                                Button(action: {
                                    if cost.isPaidThisMonth() {
                                        costToUnpay = cost
                                    } else {
                                        costToPay = cost
                                    }
                                }) {
                                    if cost.isPaidThisMonth() {
                                        VStack(alignment: .trailing) {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title)
                                            if let payer = cost.paidByWho {
                                                Text(payer).font(.system(size: 10, weight: .bold)).foregroundStyle(.green)
                                            }
                                        }
                                    } else {
                                        Image(systemName: "circle").foregroundStyle(.gray.opacity(0.3)).font(.title)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
                .refreshable { await shareManager.manualRefresh(context: modelContext) }
            }
            .navigationTitle("Costos Fijos")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        forceUpdateNow()
                    } label: {
                        if isSyncingManually {
                            ProgressView().controlSize(.small)
                        } else {
                            HStack {
                                Image(systemName: "arrow.clockwise.icloud.fill")
                                Text("Unificar").font(.caption).bold()
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddCost = true }) { Image(systemName: "plus") }
                }
            }
            .onAppear {
                print("📡 FixedCostsView: Escaneo automático activado.")
                shareManager.syncOnlyVencimientosYAhorros(context: modelContext)
            }
            .sheet(isPresented: $showingAddCost) {
                AddFixedCostView(sharedLedger: ledgers.first)
            }
            .sheet(item: $costToPay) { cost in
                AddExpenseView(preFilledCost: cost)
            }
            .sheet(item: $costToEdit) { cost in
                EditFixedCostView(cost: cost, sharedLedger: ledgers.first)
            }
            .alert(item: $costToUnpay) { cost in
                Alert(
                    title: Text("¿Anular pago?"),
                    message: Text("Se borrará el gasto del historial."),
                    primaryButton: .destructive(Text("Borrar")) { deleteLinkedExpense(for: cost) },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    // 🚀 FUNCIÓN DE FUERZA BRUTA REFORZADA CON UNIFICACIÓN DE MOCHILA
    func forceUpdateNow() {
        print("\n🌀 === INICIANDO REPARACIÓN DE IDENTIDAD FAMILIAR === ")
        isSyncingManually = true
        
        Task {
            // 1. Traemos los datos de la nube primero
            shareManager.syncOnlyVencimientosYAhorros(context: modelContext)
            
            // 2. Esperamos descarga profunda (un poco más de tiempo para seguridad)
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            
            await MainActor.run {
                modelContext.processPendingChanges()
                
                // 3. 🔍 UNIFICAR MOCHILAS (LEDGERS)
                // Buscamos cuál es el Ledger "bueno" (el que viene de la nube o tiene más gastos)
                let allLedgers = (try? modelContext.fetch(FetchDescriptor<FamilyLedger>())) ?? []
                if allLedgers.count > 1 {
                    print("⚠️ Detectados \(allLedgers.count) libros familiares. Unificando...")
                    
                    // El ganador es el que ya tiene tildes verdes (indicador de que viene de la nube compartida)
                    let winner = allLedgers.first(where: { ledger in
                        (ledger.fixedCosts?.contains(where: { $0.lastPaidPeriod != nil }) ?? false)
                    }) ?? allLedgers.first!
                    
                    for ledger in allLedgers where ledger.id != winner.id {
                        print("🚚 Mudando gastos de Mochila \(ledger.id.uuidString.prefix(4)) a Mochila \(winner.id.uuidString.prefix(4))")
                        ledger.fixedCosts?.forEach { $0.ledger = winner }
                        ledger.savingGoals?.forEach { $0.ledger = winner }
                        modelContext.delete(ledger)
                    }
                }
                
                // 4. 🧹 FUSIÓN AGRESIVA POR NOMBRE (HARD RESET DE IDS)
                let descriptor = FetchDescriptor<FixedCost>(sortBy: [SortDescriptor(\FixedCost.title)])
                if let allCosts = try? modelContext.fetch(descriptor) {
                    let grouped = Dictionary(grouping: allCosts, by: { $0.title })
                    
                    for (title, duplicates) in grouped where duplicates.count > 1 {
                        print("⚠️ Detectado duplicado para: \(title). Iniciando fusión...")
                        
                        // Buscamos el que tenga datos reales de pago (el que vino de la nube)
                        let recordToKeep = duplicates.first(where: { $0.lastPaidPeriod != nil }) ?? duplicates.first!
                        
                        for item in duplicates where item.id != recordToKeep.id {
                            print("🗑 Borrando clon local ID: \(item.id.uuidString.prefix(4)) para adoptar versión de nube.")
                            modelContext.delete(item)
                        }
                    }
                }
                
                try? modelContext.save()
                modelContext.processPendingChanges()
                
                // 5. REPORTE FINAL DE VERIFICACIÓN
                let finalLedger = (try? modelContext.fetch(FetchDescriptor<FamilyLedger>()))?.first
                print("\n✅ REPARACIÓN TERMINADA")
                print("🏠 Mochila Unificada Final ID: \(finalLedger?.id.uuidString.prefix(8) ?? "ERROR")")
                
                for cost in (try? modelContext.fetch(FetchDescriptor<FixedCost>(sortBy: [SortDescriptor(\FixedCost.dueDay)]))) ?? [] {
                    let pagado = cost.isPaidThisMonth() ? "✅" : "❌"
                    print("   🧬 [\(cost.title)] -> ID: \(cost.id.uuidString.prefix(8)) | Estado: \(pagado)")
                }
                
                isSyncingManually = false
                print("=====================================================\n")
            }
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
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets { modelContext.delete(fixedCosts[index]) }
            try? modelContext.save()
        }
    }
}

// MARK: - VISTAS DE SOPORTE

struct AddFixedCostView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var sharedLedger: FamilyLedger?
    @State private var title = ""; @State private var amountString = ""; @State private var dueDay = 10; @State private var icon = "bolt.fill"
    let icons = ["bolt.fill", "flame.fill", "drop.fill", "wifi", "phone.fill", "house.fill", "car.fill", "cart.fill", "heart.fill", "graduationcap.fill", "creditcard.fill", "tv.fill"]
    var body: some View {
        NavigationStack {
            Form {
                Section("Detalle") {
                    TextField("Nombre", text: $title)
                    HStack { Text("$"); TextField("Monto Aprox.", text: $amountString).keyboardType(.numberPad).onChange(of: amountString) { _, newValue in amountString = formatCurrency(newValue) } }
                }
                Section("Día de Pago") { Picker("Día", selection: $dueDay) { ForEach(1...31, id: \.self) { Text("Día \($0)").tag($0) } } }
            }
            .navigationTitle("Nuevo Costo")
            .toolbar {
                Button("Guardar") {
                    let cleanAmount = Double(amountString.replacingOccurrences(of: ".", with: "")) ?? 0.0
                    let newCost = FixedCost(title: title, amount: cleanAmount, icon: icon, dueDay: dueDay)
                    newCost.ledger = sharedLedger
                    modelContext.insert(newCost); try? modelContext.save(); dismiss()
                }.disabled(title.isEmpty)
            }
        }
    }
    func formatCurrency(_ input: String) -> String {
        let clean = input.filter { "0123456789".contains($0) }; guard let number = Int(clean) else { return "" }
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = "."; f.locale = Locale(identifier: "es_AR")
        return f.string(from: NSNumber(value: number)) ?? ""
    }
}

struct EditFixedCostView: View {
    @Environment(\.dismiss) var dismiss; @Environment(\.modelContext) var modelContext; @Bindable var cost: FixedCost; var sharedLedger: FamilyLedger?
    @State private var amountString = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre", text: $cost.title)
                TextField("Monto", text: $amountString).keyboardType(.numberPad).onChange(of: amountString) { _, nv in amountString = formatCurrency(nv) }
                Picker("Día", selection: $cost.dueDay) { ForEach(1...31, id: \.self) { Text("Día \($0)").tag($0) } }
            }
            .navigationTitle("Editar")
            .toolbar { Button("Listo") {
                cost.amount = Double(amountString.replacingOccurrences(of: ".", with: "")) ?? 0.0
                if cost.ledger == nil { cost.ledger = sharedLedger }
                try? modelContext.save(); dismiss()
            } }
            .onAppear { amountString = formatCurrency(String(Int(cost.amount))) }
        }
    }
    func formatCurrency(_ input: String) -> String {
        let clean = input.filter { "0123456789".contains($0) }; guard let number = Int(clean) else { return "" }
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = "."; f.locale = Locale(identifier: "es_AR")
        return f.string(from: NSNumber(value: number)) ?? ""
    }
}
