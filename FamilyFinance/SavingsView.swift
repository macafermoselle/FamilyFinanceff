import SwiftUI
import SwiftData

struct SavingsView: View {
    @Environment(\.modelContext) private var modelContext
    // Traemos los ahorros "vivos" para la lista
    @Query var savings: [SavingGoal]
    
    // Controlamos las ventanas
    @State private var showingAddGoal = false
    @State private var showingBuyUSD = false
    
    // Filtros
    var arsSavings: [SavingGoal] { savings.filter { $0.currency == "ARS" } }
    var usdSavings: [SavingGoal] { savings.filter { $0.currency == "USD" } }
    
    var body: some View {
        NavigationStack {
            List {
                // SECCIÓN 1: ACCIONES
                Section {
                    Button(action: { showingBuyUSD = true }) {
                        Label("Registrar Compra de Dólares", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.green)
                            .fontWeight(.bold)
                    }
                }
                
                // SECCIÓN 2: CAJAS EN DÓLARES
                if !usdSavings.isEmpty {
                    Section("En Dólares (USD)") {
                        ForEach(usdSavings) { goal in
                            SavingRow(goal: goal, color: .green)
                        }
                        .onDelete(perform: deleteGoal)
                    }
                }
                
                // SECCIÓN 3: CAJAS EN PESOS
                Section("En Pesos (ARS)") {
                    if arsSavings.isEmpty {
                        Text("No tienes ahorros en pesos.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(arsSavings) { goal in
                            SavingRow(goal: goal, color: .blue)
                        }
                        .onDelete(perform: deleteGoal)
                    }
                }
            }
            .navigationTitle("Mis Ahorros")
            .toolbar {
                Button(action: { showingAddGoal = true }) {
                    Image(systemName: "plus")
                }
            }
            // Ventana para agregar nueva meta
            .sheet(isPresented: $showingAddGoal) {
                AddSavingView()
            }
            // Ventana para comprar dólares
            .sheet(isPresented: $showingBuyUSD) {
                BuyDollarsView(availableGoals: savings) { usdAmount, totalPesos, goalID in
                    // Llamamos a la función "segura" que creamos abajo
                    processPurchaseSafe(usdAmount: usdAmount, totalPesos: totalPesos, goalID: goalID)
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    // --- FUNCIÓN SEGURA PARA PROCESAR LA COMPRA ---
    func processPurchaseSafe(usdAmount: Double, totalPesos: Double, goalID: UUID) {
        // Truco del tiempo: Esperamos a que la ventana se cierre completamente
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            
            // 1. BÚSQUEDA FRESCA (Clave para evitar el freeze)
            // No usamos la lista 'savings' de la UI, pedimos el dato directo al disco.
            let descriptor = FetchDescriptor<SavingGoal>(predicate: #Predicate { $0.id == goalID })
            
            do {
                if let goal = try modelContext.fetch(descriptor).first {
                    // 2. Modificamos
                    goal.currentAmount += usdAmount
                    
                    // 3. Creamos el Gasto
                    let expense = Expense(
                        title: "Compra \(Int(usdAmount)) USD",
                        amount: totalPesos,
                        date: Date(),
                        category: "Ahorro/Inversión",
                        createdBy: "Yo",
                        paymentMethod: "Efectivo",
                        installments: 1
                    )
                    modelContext.insert(expense)
                    
                    // 4. GUARDADO EXPLÍCITO (Para asegurar que quede en disco sí o sí)
                    try modelContext.save()
                    print("✅ Datos guardados y asegurados en disco.")
                }
            } catch {
                print("❌ Error al procesar compra: \(error)")
            }
        }
    }
    
    private func deleteGoal(offsets: IndexSet) {
        withAnimation {
            for index in offsets { modelContext.delete(savings[index]) }
        }
    }
}

// MARK: - FILA DE AHORRO (BLINDADA CONTRA ERRORES VISUALES)
// Esta es la versión corregida para que no te de el error "NaN"
struct SavingRow: View {
    let goal: SavingGoal
    let color: Color
    
    var progress: Double {
        let target = goal.targetAmount
        let current = goal.currentAmount
        // Si la meta es 0 o hay error matemático, devolvemos 0 para no romper la UI
        if target <= 0 || target.isNaN || current.isNaN { return 0.0 }
        return current / target
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock.square.fill").foregroundStyle(color)
                Text(goal.name).font(.headline)
                Spacer()
                Text(goal.currentAmount.formatted(.currency(code: goal.currency)))
                    .bold().foregroundStyle(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Cálculo de ancho a prueba de fallos
                    let width = CGFloat(progress) * geo.size.width
                    let safeWidth = width.isNaN ? 0 : min(width, geo.size.width)
                    
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .frame(width: safeWidth, height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("\(Int(progress * 100))%")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Meta: \(goal.targetAmount.formatted(.currency(code: goal.currency)))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AGREGAR AHORRO (Sin cambios, solo para que compile todo junto)
