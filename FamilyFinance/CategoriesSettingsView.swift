import SwiftUI
import SwiftData

struct CategoriesSettingsView: View {
    @Query(sort: \ExpenseCategory.name) var categories: [ExpenseCategory]
    @Environment(\.modelContext) var modelContext
    
    @State private var categoryName = ""
    @State private var selectedIcon = "tag.fill"
    
    // DEFINIMOS EL MAPA: "Icono Técnico" : "Nombre Lindo"
    // Usamos un Array de Tuplas para mantener el orden que queramos
    let iconMap: [(icon: String, name: String)] = [
        ("cart.fill", "Supermercado"),
        ("bag.fill", "Compras / Shopping"),
        ("fork.knife", "Restaurantes / Comida"),
        ("cup.and.saucer.fill", "Café / Merienda"),
        ("house.fill", "Casa / Alquiler"),
        ("bolt.fill", "Servicios (Luz/Gas)"),
        ("car.fill", "Auto / Nafta"),
        ("bus.fill", "Transporte Público"),
        ("airplane", "Viajes"),
        ("cross.case.fill", "Salud / Farmacia"),
        ("heart.fill", "Bienestar"),
        ("pawprint.fill", "Mascotas"),
        ("dumbbell.fill", "Deporte / Gym"),
        ("figure.run", "Actividades"),
        ("stroller.fill", "Bebé / Niños"),
        ("graduationcap.fill", "Educación"),
        ("tshirt.fill", "Ropa"),
        ("gift.fill", "Regalos"),
        ("gamecontroller.fill", "Juegos"),
        ("film.fill", "Cine / Streaming"),
        ("music.note", "Música"),
        ("creditcard.fill", "Tarjetas / Deudas"),
        ("star.fill", "Varios / General"),
        ("banknote.fill", "Impuestos")
    ]

    var body: some View {
        Form {
            Section("Nueva Categoría") {
                TextField("Nombre (Ej: Farmacia)", text: $categoryName)
                
                // PICKER MEJORADO CON TEXTO LINDO 🎨
                Picker("Icono", selection: $selectedIcon) {
                    ForEach(iconMap, id: \.icon) { item in
                        // Mostramos el Nombre Lindo, pero guardamos el Icono Técnico
                        Label(item.name, systemImage: item.icon)
                            .tag(item.icon)
                    }
                }
                .pickerStyle(.navigationLink) // Abre la lista limpia
                
                Button(action: addCategory) {
                    Text("Guardar Categoría")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(categoryName.isEmpty)
            }
            
            Section("Tus Categorías") {
                if categories.isEmpty {
                    ContentUnavailableView("Sin Categorías", systemImage: "tray", description: Text("Agregá tus propias categorías arriba."))
                } else {
                    List {
                        ForEach(categories) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundStyle(.blue)
                                    .frame(width: 30)
                                    .font(.title3)
                                
                                Text(category.name)
                                    .font(.headline)
                                
                                Spacer()
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    modelContext.delete(category)
                                } label: {
                                    Label("Borrar", systemImage: "trash")
                                }
                                
                                Button {
                                    categoryName = category.name
                                    selectedIcon = category.icon
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Gestionar Categorías")
    }
    
    func addCategory() {
        let newCat = ExpenseCategory(name: categoryName, icon: selectedIcon)
        modelContext.insert(newCat)
        
        categoryName = ""
        selectedIcon = "tag.fill"
    }
}
