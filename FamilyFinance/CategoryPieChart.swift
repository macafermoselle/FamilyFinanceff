import SwiftUI
import Charts
import SwiftData

struct CategoryPieChart: View {
    let expenses: [Expense]
    var data: [(category: String, amount: Double)] {
        let grouped = Dictionary(grouping: expenses) { $0.category }
        return grouped.map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }.sorted { $0.amount > $1.amount }
    }
    var body: some View {
        Chart(data, id: \.category) { item in SectorMark(angle: .value("Monto", item.amount), innerRadius: .ratio(0.6), angularInset: 1).foregroundStyle(by: .value("Categoría", item.category)).cornerRadius(5) }.frame(height: 200).padding().background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(15)
    }
}
