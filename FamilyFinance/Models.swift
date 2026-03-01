import Foundation
import SwiftData

// MARK: - ANCLA FAMILIAR (EL LIBRO CONTABLE)
@Model
final class FamilyLedger {
    var id: UUID = UUID()
    var name: String = "Billetera Familiar"
    
    // 👇 RELACIONES INVERSAS (MANDATORIAS PARA CLOUDKIT)
    @Relationship(inverse: \SavingGoal.ledger) var savingGoals: [SavingGoal]? = []
    @Relationship(inverse: \FixedCost.ledger) var fixedCosts: [FixedCost]? = []
    
    // 👇 RESTAURADO PARA CLOUDKIT: Aunque no los usemos para compartir masivamente,
    // estructuralmente deben existir porque Income tiene la propiedad ledger.
    @Relationship(inverse: \Income.ledger) var incomes: [Income]? = []
    
    init(name: String = "Billetera Familiar") {
        self.name = name
    }
}

// 1. GASTO (100% Privado)
@Model
final class Expense {
    var id: UUID = UUID()
    var title: String = ""
    var amount: Double = 0.0
    var date: Date = Date()
    var category: String = "Varios"
    var createdBy: String = "Yo"
    var paymentMethod: String = "Efectivo"
    var installments: Int = 1
    var isHormiga: Bool = false
    var isMine: Bool = true
    var ownerId: String = ""
    var vacationName: String?
    
    @Relationship(inverse: \CreditCard.expenses)
    var card: CreditCard?
    
    // Nota: Expense NO tiene ledger, así que no necesita inverso en FamilyLedger. Mochila liviana.
    
    init(title: String, amount: Double, date: Date, category: String, isHormiga: Bool = false, createdBy: String = "Yo", paymentMethod: String = "Efectivo", installments: Int = 1, card: CreditCard? = nil, vacationName: String? = nil, isMine: Bool = true, ownerId: String = "") {
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
        self.isHormiga = isHormiga
        self.createdBy = createdBy
        self.paymentMethod = paymentMethod
        self.installments = installments
        self.card = card
        self.vacationName = vacationName
        self.isMine = isMine
        self.ownerId = ownerId
    }
}

// 2. TARJETA DE CRÉDITO
@Model
final class CreditCard {
    var id: UUID = UUID()
    var name: String = ""
    var bankName: String = ""
    var last4Digits: String = ""
    var closingDay: Int = 1
    var dueDay: Int = 10
    var colorHex: String = "blue"
    var expenses: [Expense]? = []
    var ownerId: String = ""
    
    init(name: String, bankName: String, last4Digits: String, closingDay: Int, dueDay: Int, colorHex: String) {
        self.name = name
        self.bankName = bankName
        self.last4Digits = last4Digits
        self.closingDay = closingDay
        self.dueDay = dueDay
        self.colorHex = colorHex
    }
}

// 3. COSTO FIJO (COMPARTIDO 🤝)
@Model
final class FixedCost {
    var id: UUID = UUID()
    var title: String = ""
    var amount: Double = 0.0
    var icon: String = "calendar"
    var dueDay: Int = 1
    var category: String = "Varios"
    
    var ledger: FamilyLedger?
    var lastPaidPeriod: String?
    var paidByWho: String?
    
    init(title: String, amount: Double, icon: String = "calendar", dueDay: Int = 1, category: String = "Varios") {
        self.title = title
        self.amount = amount
        self.icon = icon
        self.dueDay = dueDay
        self.category = category
    }
    
    func isPaidThisMonth() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-yyyy"
        return lastPaidPeriod == formatter.string(from: Date())
    }
    
    func markAsPaid(by name: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-yyyy"
        self.lastPaidPeriod = formatter.string(from: Date())
        self.paidByWho = name
    }
    
    func markAsUnpaid() {
        self.lastPaidPeriod = nil
        self.paidByWho = nil
    }
}

// 4. INGRESO
@Model
final class Income {
    var id: UUID = UUID()
    var title: String = ""
    var amount: Double = 0.0
    var date: Date = Date()
    var category: String = "Varios"
    var ownerId: String = ""
    var createdBy: String = "Yo"
    
    // 👇 Propiedad restaurada para que AddIncomeView no de error
    var ledger: FamilyLedger?
    
    init(title: String, amount: Double, date: Date = Date(), category: String = "Varios", ownerId: String = "", createdBy: String = "Yo") {
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
        self.ownerId = ownerId
        self.createdBy = createdBy
    }
}

// 5. INGRESO FIJO
@Model
final class FixedIncome {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0.0
    var dayOfMonth: Int = 1
    var lastCollectedMonth: String?
    
    init(name: String, amount: Double, dayOfMonth: Int) {
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

// 6. PRESUPUESTO
@Model
final class CategoryBudget {
    var id: UUID = UUID()
    var category: String = ""
    var limit: Double = 0.0
    init(category: String, limit: Double) { self.category = category; self.limit = limit }
}

// 7. META DE AHORRO (COMPARTIDA 🤝)
@Model
final class SavingGoal {
    var name: String = ""
    var targetAmount: Double = 0.0
    var currentAmount: Double = 0.0
    var deadline: Date = Date()
    var icon: String = "star.fill"
    var currency: String = "ARS"
    var ledger: FamilyLedger?
    
    @Relationship(deleteRule: .cascade, inverse: \SavingMovement.goal)
    var movements: [SavingMovement]? = []
    
    init(name: String, targetAmount: Double, currentAmount: Double = 0.0, deadline: Date = Date(), icon: String = "star.fill", currency: String = "ARS") {
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.deadline = deadline
        self.icon = icon
        self.currency = currency
    }
}

// 8. CATEGORÍA
@Model
class ExpenseCategory {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "tag"
    init(name: String, icon: String = "questionmark.circle") { self.name = name; self.icon = icon }
}

// 9. VACACIONES
@Model
final class Vacation {
    var id: UUID = UUID()
    var name: String = ""
    var startDate: Date = Date()
    var isActive: Bool = true
    init(name: String, startDate: Date = Date(), isActive: Bool = true) { self.name = name; self.startDate = startDate; self.isActive = isActive }
}

// 10. MOVIMIENTO DE AHORRO
@Model
final class SavingMovement {
    var id: UUID = UUID()
    var date: Date = Date()
    var amount: Double = 0.0
    var type: String = "Depósito"
    var user: String = ""
    var ownerId: String = ""
    var note: String = ""
    var goal: SavingGoal?
    
    init(amount: Double, type: String, user: String, ownerId: String = "", note: String = "") {
        self.amount = amount
        self.type = type
        self.user = user
        self.ownerId = ownerId
        self.note = note
    }
}
