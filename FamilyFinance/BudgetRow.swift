import SwiftUI
import SwiftData

struct BudgetDashboardRow: View {
    let budget: CategoryBudget
    let expenses: [Expense] // Le pasamos TODOS los gastos para que filtre
    
    // Calculamos cuánto gastamos este mes en ESTA categoría
    var spentAmount: Double {
        let currentMonth = Date()
        return expenses.filter { expense in
            expense.category == budget.category &&
            Calendar.current.isDate(expense.date, equalTo: currentMonth, toGranularity: .month)
        }.reduce(0) { total, expense in
            // Si es tarjeta en cuotas, sumamos la cuota del mes (simplificado: total / cuotas)
            // O sumamos el total si preferís ver el impacto total de la compra.
            // Por ahora sumamos el monto directo para simplificar:
            return total + expense.amount
        }
    }
    
    var progress: Double {
        guard budget.limit > 0 else { return 0 }
        return spentAmount / budget.limit
    }
    
    // Semáforo de colores
    var barColor: Color {
        if progress >= 1.0 { return .red }      // Te pasaste
        if progress >= 0.8 { return .orange }   // Alerta (80%)
        return .green                           // Venís bien
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Título y Montos
            HStack {
                Text(budget.category)
                    .font(.subheadline)
                    .bold()
                
                Spacer()
                
                Text("\(spentAmount.formatted(.currency(code: "ARS"))) / \(budget.limit.formatted(.currency(code: "ARS")))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            // La Barrita Visual
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Fondo gris (el total)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Relleno de color (lo gastado)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(barColor)
                        .frame(width: min(CGFloat(progress) * geo.size.width, geo.size.width), height: 8)
                }
            }
            .frame(height: 8)
            
            // Mensaje de alerta si te pasaste
            if progress >= 1.0 {
                Text("⚠️ Presupuesto excedido")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .bold()
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
