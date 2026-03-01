import SwiftUI
import Charts // IMPORTANTE: El framework de gráficos de Apple
import SwiftData

struct ExpensesChart: View {
    var expenses: [Expense] // Recibimos los gastos brutos
    
    // Filtramos solo lo de este mes para el gráfico
    var currentMonthData: [(category: String, amount: Double)] {
        let currentMonth = Date()
        
        // 1. Filtramos gastos de este mes (Efectivo) + Cuotas que caen hoy
        // Nota: Para simplificar el gráfico visual, aquí sumaremos el TOTAL de los gastos
        // realizados este mes, para saber "En qué estoy gastando ahora".
        let thisMonthExpenses = expenses.filter {
            Calendar.current.isDate($0.date, equalTo: currentMonth, toGranularity: .month)
        }
        
        // 2. Agrupamos por categoría (Ej: ["Super": 5000, "Super": 2000] -> "Super": 7000)
        let grouped = Dictionary(grouping: thisMonthExpenses, by: { $0.category })
        
        // 3. Formateamos para el gráfico
        return grouped.map { (key, value) in
            (category: key, amount: value.reduce(0) { $0 + $1.amount })
        }.sorted { $0.amount > $1.amount } // Ordenamos del más caro al más barato
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Distribución de Gastos (Mes Actual)")
                .font(.headline)
                .padding(.horizontal)
            
            if currentMonthData.isEmpty {
                Text("Aún no hay datos suficientes este mes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                // EL GRÁFICO
                Chart(currentMonthData, id: \.category) { item in
                    SectorMark(
                        angle: .value("Gasto", item.amount),
                        innerRadius: .ratio(0.6), // Esto lo hace tipo "Dona"
                        angularInset: 2 // Espacio entre cortes
                    )
                    .foregroundStyle(by: .value("Categoría", item.category))
                    .cornerRadius(5)
                }
                .frame(height: 200)
                .padding()
                
                // LEYENDA (La lista de abajo)
                VStack(spacing: 10) {
                    ForEach(currentMonthData.prefix(3), id: \.category) { item in
                        HStack {
                            Circle()
                                .fill(Color.gray) // Aquí podríamos usar colores dinámicos
                                .frame(width: 8, height: 8)
                            Text(item.category)
                                .font(.caption)
                            Spacer()
                            Text(item.amount.formatted(.currency(code: "ARS")))
                                .font(.caption)
                                .bold()
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 2)
    }
}
