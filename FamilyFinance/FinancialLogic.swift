import Foundation
extension Array where Element == Expense {
    /// Calcula la deuda total de tarjeta para un mes y año específicos
    func totalCreditDebt(for date: Date) -> Double {
        let calendar = Calendar.current
        let targetComponents = calendar.dateComponents([.year, .month], from: date)
        
        return self.filter { $0.paymentMethod == "Tarjeta de Crédito" }.reduce(0.0) { total, expense in
            let closingDay = expense.card?.closingDay ?? 24
            let purchaseComponents = calendar.dateComponents([.day, .month, .year], from: expense.date)
            
            var startPaymentDate = expense.date
            
            // Si compró después del cierre, la primera cuota cae el mes siguiente
            if let day = purchaseComponents.day, day > closingDay {
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: expense.date) {
                    startPaymentDate = nextMonth
                }
            }
            
            // Calculamos el rango de meses que dura la deuda
            // Si es 1 cuota, termina el mismo mes. Si son 3, termina en m+2.
            if let endPaymentDate = calendar.date(byAdding: .month, value: Swift.max(0, expense.installments - 1), to: startPaymentDate) {
                
                let startMonth = calendar.dateComponents([.year, .month], from: startPaymentDate)
                let endMonth = calendar.dateComponents([.year, .month], from: endPaymentDate)
                
                // Comparamos si el mes buscado está entre el inicio y el fin del plan de cuotas
                let isAfterOrEqualStart = (targetComponents.year! > startMonth.year!) || (targetComponents.year! == startMonth.year! && targetComponents.month! >= startMonth.month!)
                let isBeforeOrEqualEnd = (targetComponents.year! < endMonth.year!) || (targetComponents.year! == endMonth.year! && targetComponents.month! <= endMonth.month!)
                
                if isAfterOrEqualStart && isBeforeOrEqualEnd {
                    let installmentValue = expense.amount / Double(Swift.max(1, expense.installments))
                    return total + installmentValue
                }
            }
            return total
        }
    }
}
