import SwiftUI
import Charts
import SwiftData

struct CategoryPieChart: View {
    var expenses: [Expense]
    
    // Agrupamos los gastos por categoría y sumamos sus montos
    var data: [(category: String, amount: Double)] {
        let grouped = Dictionary(grouping: expenses, by: { $0.category })
        return grouped.map { (key, values) in
            (category: key, amount: values.reduce(0) { $0 + $1.amount })
        }.sorted { $0.amount > $1.amount } // Ordenamos de mayor a menor
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Gastos por Categoría")
                .font(.headline)
                .padding(.bottom, 5)
            
            if data.isEmpty {
                Text("No hay gastos registrados este mes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            } else {
                Chart(data, id: \.category) { item in
                    SectorMark(
                        angle: .value("Gasto", item.amount),
                        innerRadius: .ratio(0.6), // Esto lo hace tipo "Dona"
                        angularInset: 1.5 // Espacio entre rebanadas
                    )
                    .foregroundStyle(by: .value("Categoría", item.category))
                    .cornerRadius(5)
                }
                .frame(height: 200)
                // Opcional: Personalizar colores si quieres
                .chartForegroundStyleScale([
                    "Supermercado": .blue,
                    "Comida": .orange,
                    "Transporte": .gray,
                    "Servicios": .yellow,
                    "Farmacia": .red,
                    "Ropa": .purple,
                    "Ocio": .pink,
                    "Varios": .green
                ])
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
