import Foundation
import SwiftData

// 1. GASTO
@Model
final class Expense {
    var id: UUID
    var title: String
    var amount: Double
    var date: Date
    var category: String
    var createdBy: String
    var paymentMethod: String
    var installments: Int
    
    // Relación opcional con tarjeta
    var card: CreditCard?
    
    // AQUÍ ESTÁ EL CAMBIO: Agregamos 'card: CreditCard? = nil' al final
    init(title: String, amount: Double, date: Date, category: String, createdBy: String = "Yo", paymentMethod: String = "Efectivo", installments: Int = 1, card: CreditCard? = nil) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
        self.createdBy = createdBy
        self.paymentMethod = paymentMethod
        self.installments = installments
        self.card = card
    }
}

// 2. TARJETA
@Model
final class CreditCard {
    var id: UUID
    var name: String
    var bankName: String
    var last4Digits: String
    var closingDay: Int
    var dueDay: Int
    var colorHex: String
    
    init(name: String, bankName: String, last4Digits: String, closingDay: Int, dueDay: Int, colorHex: String) {
        self.id = UUID()
        self.name = name
        self.bankName = bankName
        self.last4Digits = last4Digits
        self.closingDay = closingDay
        self.dueDay = dueDay
        self.colorHex = colorHex
    }
}

// 3. COSTO FIJO
@Model
final class FixedCost {
    var id: UUID
    var title: String
    var amount: Double
    var icon: String
    var dueDay: Int // <--- ¡Esto es lo que faltaba!
    
    init(title: String, amount: Double, icon: String = "calendar", dueDay: Int = 1) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.icon = icon
        self.dueDay = dueDay
    }
}

// 4. INGRESO (AQUÍ ESTÁ EL QUE FALTABA)
@Model
final class Income {
    var id: UUID
    var title: String
    var amount: Double
    var date: Date
    
    init(title: String, amount: Double, date: Date) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.date = date
    }
}

// 5. INGRESO FIJO
@Model
final class FixedIncome {
    var id: UUID
    var name: String
    var amount: Double
    var dayOfMonth: Int
    var lastCollectedMonth: String?
    
    init(name: String, amount: Double, dayOfMonth: Int) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.dayOfMonth = dayOfMonth
    }
    
    func isCollected() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-yyyy"
        let currentMonth = formatter.string(from: Date())
        return lastCollectedMonth == currentMonth
    }
}


// 6. PRESUPUESTO POR CATEGORÍA
@Model
final class CategoryBudget {
    var id: UUID
    var category: String // Ej: "Ocio"
    var limit: Double    // Ej: 400.000
    
    init(category: String, limit: Double) {
        self.id = UUID()
        self.category = category
        self.limit = limit
    }
}


// 7. META DE AHORRO
@Model
final class SavingGoal {
    var id: UUID
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var currency: String // ARS o USD
    var icon: String
    
    init(name: String, targetAmount: Double, currentAmount: Double, currency: String = "ARS", icon: String = "lock.square.fill") {
        self.id = UUID()
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.currency = currency
        self.icon = icon
    }
}

// 8. CATEGORÍA PERSONALIZADA
@Model
final class ExpenseCategory {
    var id: UUID
    var name: String      // Ej: "Supermercado"
    var icon: String      // Ej: "cart.fill"
    
    init(name: String, icon: String) {
        self.id = UUID()
        self.name = name
        self.icon = icon
    }
}

