import SwiftUI
import SwiftData

struct CategoriesSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.name) var categories: [ExpenseCategory]
    
    @State private var showingAdd = false
    @State private var newName = ""
    @State private var newIcon = "tag.fill"
    
    // Lista de iconos disponibles para elegir
    let availableIcons = ["cart.fill", "fork.knife", "car.fill", "bolt.fill", "cross.case.fill", "tshirt.fill", "popcorn.fill", "bag.fill", "house.fill", "gift.fill", "pawprint.fill", "airplane", "book.fill", "fuelpump.fill", "gym.bag.fill"]
    
    var body: some View {
        List {
            ForEach(categories) { category in
                HStack {
                    Image(systemName: category.icon)
                        .foregroundStyle(.blue)
                        .frame(width: 30)
                    Text(category.name)
                }
            }
            .onDelete(perform: deleteCategories)
        }
        .navigationTitle("Categorías")
        .toolbar {
            Button(action: { showingAdd = true }) {
                Image(systemName: "plus")
            }
        }
        .alert("Nueva Categoría", isPresented: $showingAdd) {
            TextField("Nombre", text: $newName)
            Button("Cancelar", role: .cancel) { newName = "" }
            Button("Guardar") {
                let newCat = ExpenseCategory(name: newName, icon: newIcon)
                modelContext.insert(newCat)
                newName = ""
            }
        } message: {
            Text("Escribe el nombre de la categoría. Se usará un icono genérico por defecto.")
        }
    }
    
    private func deleteCategories(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(categories[index])
            }
        }
    }
}
