import SwiftUI
import CloudKit
import Combine
import SwiftData

class CloudSharingManager: ObservableObject {
    static let shared = CloudSharingManager()
    
    @Published var isSharing = false
    @Published var share: CKShare?
    @Published var error: String?
    @Published var connectionStatus: String = "Iniciando..."
    @Published var isSyncing = false
    @Published var syncCompletedSuccessfully = false
    
    @Published var technicalLogs: [String] = []
    @Published var foundRecordTypes: [String: Int] = [:]
    @Published var totalRecordsFound: Int = 0
    
    @Published var localExpenseCount: Int = 0
    @Published var localIncomeCount: Int = 0
    @Published var localCardCount: Int = 0
    @Published var localCategoryCount: Int = 0
    @Published var localSavingsCount: Int = 0
    
    @Published var detectedCategoryNames: [String] = []
    @Published var detectedCardNames: [String] = []
    @Published var detectedSavingGoals: [(name: String, current: Double, target: Double, currency: String)] = []
    @Published var detectedIncomes: [(title: String, amount: Double, date: Date)] = []
    @Published var detectedExpenses: [(title: String, amount: Double, date: Date, category: String, method: String, cardName: String?, isHormiga: Bool, mine: Bool)] = []
    
    private let container = CKContainer(identifier: "iCloud.com.carya.familyfinances.2026")
    private let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        addLog("🚀 BlackBox iniciada.")
        checkShareStatus()
        setupRemoteChangeObserver()
    }
    
    private func setupRemoteChangeObserver() {
        NotificationCenter.default.publisher(for: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"))
            .receive(on: RunLoop.main)
            .sink { _ in
                self.addLog("⚡️ ¡CAMBIO DETECTADO EN LA NUBE!")
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: RunLoop.main)
            .sink { _ in
                self.addLog("📱 App en primer plano: Lista.")
            }
            .store(in: &cancellables)
    }

    // MARK: - PUENTE SATELITAL 1: VENCIMIENTOS
    func forcePushPaymentToCloud(costTitle: String, period: String?, payer: String?) {
        Task {
            await MainActor.run { self.addLog("🚀 Disparando pago al satélite: \(costTitle)") }
            let predicate = NSPredicate(format: "CD_title == %@", costTitle)
            let query = CKQuery(recordType: "CD_FixedCost", predicate: predicate)
            
            let updateRecord: (CKRecord) -> Void = { record in
                record["CD_lastPaidPeriod"] = period
                record["CD_paidByWho"] = payer
            }
            
            if self.connectionStatus == "Invitado" {
                if let zones = try? await self.container.sharedCloudDatabase.allRecordZones() {
                    for zone in zones {
                        if let (matchResults, _) = try? await self.container.sharedCloudDatabase.records(matching: query, inZoneWith: zone.zoneID),
                           let firstMatch = matchResults.first, let record = try? firstMatch.1.get() {
                            updateRecord(record)
                            try? await self.container.sharedCloudDatabase.save(record)
                            await MainActor.run { self.addLog("☁️✅ ¡Éxito FACU! Pago en Compartida.") }
                            return
                        }
                    }
                }
            } else {
                let myZone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
                if let (privResults, _) = try? await self.container.privateCloudDatabase.records(matching: query, inZoneWith: myZone),
                   let firstPriv = privResults.first, let record = try? firstPriv.1.get() {
                    updateRecord(record)
                    try? await self.container.privateCloudDatabase.save(record)
                    await MainActor.run { self.addLog("☁️✅ ¡Éxito MACA! Pago en Privada.") }
                }
            }
        }
    }
    
    // MARK: - PUENTE SATELITAL 2: AHORROS CON EL "MOCHILERO" 🚀🎒
    func forcePushSavingToCloud(goalName: String, currentAmount: Double, movAmount: Double? = nil, movType: String? = nil, movUser: String? = nil, movOwner: String? = nil, movNote: String? = nil) {
        Task {
            // 👇 EL TRUCO DEL TIEMPO (Evasión de Sobreescritura VIP)
            // Esperamos 4 segundos para que Apple termine de guardar lo nativo sin borrarnos el ticket.
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            
            await MainActor.run { self.addLog("🚀 Disparando mochila: \(goalName)") }
            let predicate = NSPredicate(format: "CD_name == %@", goalName)
            let query = CKQuery(recordType: "CD_SavingGoal", predicate: predicate)
            
            let updateRecord: (CKRecord) -> Void = { record in
                // 1. Actualizamos el número grande
                record["CD_currentAmount"] = currentAmount
                
                // 2. Empacamos el ticket del movimiento adentro del mismo registro
                if let amount = movAmount, let type = movType, let user = movUser, let owner = movOwner {
                    let timestamp = Date().timeIntervalSince1970
                    let safeNote = (movNote ?? "").replacingOccurrences(of: "|", with: "-").replacingOccurrences(of: ":", with: "-")
                    
                    let payload = "\(timestamp)|\(type)|\(amount)|\(user)|\(owner)|\(safeNote)"
                    let existing = record["CD_historyHack"] as? String ?? ""
                    
                    var historyList = existing.isEmpty ? [] : existing.components(separatedBy: ":::")
                    historyList.append(payload)
                    if historyList.count > 15 { historyList.removeFirst(historyList.count - 15) }
                    record["CD_historyHack"] = historyList.joined(separator: ":::")
                    
                    self.addLog("🎒 Empacando ticket: \(type) $\(amount)")
                } else {
                    self.addLog("⚠️ Ojo: Viajando sin ticket en la mochila")
                }
            }
            
            if self.connectionStatus == "Invitado" {
                if let zones = try? await self.container.sharedCloudDatabase.allRecordZones() {
                    for zone in zones {
                        if let (matchResults, _) = try? await self.container.sharedCloudDatabase.records(matching: query, inZoneWith: zone.zoneID),
                           let firstMatch = matchResults.first, let record = try? firstMatch.1.get() {
                            updateRecord(record)
                            try? await self.container.sharedCloudDatabase.save(record)
                            await MainActor.run { self.addLog("☁️✅ ¡Éxito FACU! Ahorro actualizado.") }
                            return
                        }
                    }
                }
            } else {
                let myZone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
                if let (privResults, _) = try? await self.container.privateCloudDatabase.records(matching: query, inZoneWith: myZone),
                   let firstPriv = privResults.first, let record = try? firstPriv.1.get() {
                    updateRecord(record)
                    try? await self.container.privateCloudDatabase.save(record)
                    await MainActor.run { self.addLog("☁️✅ ¡Éxito MACA! Ahorro actualizado.") }
                }
            }
        }
    }
    
    // MARK: - FUNCIÓN PARA PULL TO REFRESH 📥
    func manualRefresh(context: ModelContext) async {
        await MainActor.run {
            self.isSyncing = true
            self.addLog("📥 Iniciando Sincronización Forzada...")
        }
        
        if self.share != nil || self.connectionStatus == "Propietario" {
            do {
                let database = self.connectionStatus == "Invitado" ? container.sharedCloudDatabase : container.privateCloudDatabase
                let defaultZone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
                self.discoverEverythingInZone(zoneID: defaultZone)
                
                if self.connectionStatus == "Invitado" {
                    let zones = try await database.allRecordZones()
                    for zone in zones {
                        self.discoverEverythingInZone(zoneID: zone.zoneID)
                    }
                }
            } catch {}
        }
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            self.repairSmallData(context: context)
            self.inspectLocalDatabase(context: context)
            self.isSyncing = false
            self.addLog("✅ Sincronización Manual Completa.")
        }
    }
    
    func addLog(_ message: String) {
        print("DEBUG: \(message)")
        DispatchQueue.main.async {
            let timestamp = Date().formatted(.dateTime.hour().minute().second())
            let uniqueMsg = "[\(timestamp)] \(message) ##\(UUID().uuidString.prefix(4))"
            
            self.technicalLogs.insert(uniqueMsg, at: 0)
            if self.technicalLogs.count > 100 { self.technicalLogs.removeLast() }
        }
    }
    
    // MARK: - GESTIÓN DE ESTADO
    func checkShareStatus() {
        addLog("🔍 Consultando estado de permisos en iCloud...")
        let shareID = CKRecord.ID(recordName: "cloudkit.share", zoneID: zoneID)
        container.privateCloudDatabase.fetch(withRecordID: shareID) { record, error in
            if let share = record as? CKShare {
                self.addLog("👑 Estatus: Organizador.")
                DispatchQueue.main.async {
                    self.share = share
                    self.isSharing = true
                    self.connectionStatus = "Organizador"
                }
            } else {
                self.addLog("🤝 Buscando invitaciones aceptadas...")
                self.fetchSharedZoneForGuest()
            }
        }
    }
    
    private func fetchSharedZoneForGuest() {
        container.sharedCloudDatabase.fetchAllRecordZones { zones, error in
            if let zones = zones, !zones.isEmpty {
                self.addLog("📦 Detectadas \(zones.count) zonas compartidas.")
                DispatchQueue.main.async {
                    self.isSharing = true
                    self.connectionStatus = "Invitado"
                }
            } else {
                self.addLog("⚠️ Sin carpetas compartidas activas.")
                DispatchQueue.main.async {
                    if self.connectionStatus != "Listo para vincular" {
                        self.connectionStatus = "Esperando Datos..."
                    }
                }
            }
        }
    }
    
    // MARK: - MODO ESCÁNER FORENSE 🕵️‍♂️
    func discoverEverythingInZone(zoneID: CKRecordZone.ID) {
        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: config])
        
        operation.recordWasChangedBlock = { recordID, result in
            if case .success(let record) = result {
                let type = record.recordType
                let name = record["CD_name"] as? String ?? record["CD_title"] as? String ?? "Sin nombre"
                
                DispatchQueue.main.async {
                    self.totalRecordsFound += 1
                    self.foundRecordTypes[type, default: 0] += 1
                    
                    if type.contains("ExpenseCategory") {
                        if !self.detectedCategoryNames.contains(name) { self.detectedCategoryNames.append(name) }
                    } else if type.contains("SavingGoal") {
                        let current = record["CD_currentAmount"] as? Double ?? 0
                        let target = record["CD_targetAmount"] as? Double ?? 0
                        let currency = record["CD_currency"] as? String ?? "ARS"
                        if !self.detectedSavingGoals.contains(where: { $0.name == name }) {
                            self.detectedSavingGoals.append((name, current, target, currency))
                        }
                    }
                }
            }
        }
        container.sharedCloudDatabase.add(operation)
    }

    func inspectLocalDatabase(context: ModelContext) {
        do {
            let cats = try context.fetch(FetchDescriptor<ExpenseCategory>())
            let exps = try context.fetch(FetchDescriptor<Expense>())
            DispatchQueue.main.async {
                self.localCategoryCount = cats.count
                self.localExpenseCount = exps.count
            }
        } catch {}
    }

    func repairSmallData(context: ModelContext) {
        self.isSyncing = true
        addLog("🛠 Iniciando Protocolo de Rescate...")
        do {
            try? context.save()
            if !detectedSavingGoals.isEmpty {
                for goal in detectedSavingGoals {
                    let searchName = goal.name
                    let descriptor = FetchDescriptor<SavingGoal>(predicate: #Predicate<SavingGoal> { $0.name == searchName })
                    if (try? context.fetchCount(descriptor)) == 0 {
                        context.insert(SavingGoal(name: searchName, targetAmount: goal.target, currentAmount: goal.current, currency: goal.currency))
                    }
                }
            }
            try context.save()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.inspectLocalDatabase(context: context)
                self.isSyncing = false
                self.addLog("✅ Billetera sincronizada.")
            }
        } catch {
            self.isSyncing = false
        }
    }

    func acceptShare(from urlString: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        DispatchQueue.main.async { self.isSyncing = true }
        addLog("📩 Uniendo al link manual...")
        
        let fetchMetaOp = CKFetchShareMetadataOperation(shareURLs: [url])
        fetchMetaOp.shouldFetchRootRecord = true
        
        fetchMetaOp.perShareMetadataResultBlock = { url, result in
            if case .success(let metadata) = result {
                let acceptOp = CKAcceptSharesOperation(shareMetadatas: [metadata])
                acceptOp.acceptSharesResultBlock = { acceptResult in
                    DispatchQueue.main.async {
                        self.isSyncing = false
                        if case .success = acceptResult {
                            self.addLog("✅ Unión manual exitosa.")
                            self.checkShareStatus()
                            completion("✅ ¡Unido!")
                        }
                    }
                }
                self.container.add(acceptOp)
            }
        }
        container.add(fetchMetaOp)
    }
    
    // MARK: - FUNCIONES DE COMPARTIR 🛠
    func createShare(completion: @escaping (CKShare?, Error?) -> Void) {
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "Billetera Familiar" as CKRecordValue
        share.publicPermission = .readWrite
        
        let modifyOp = CKModifyRecordsOperation(recordsToSave: [share], recordIDsToDelete: nil)
        modifyOp.modifyRecordsResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.share = share
                    self.isSharing = true
                    completion(share, nil)
                case .failure(let error):
                    self.error = error.localizedDescription
                    completion(nil, error)
                }
            }
        }
        container.privateCloudDatabase.add(modifyOp)
    }
    
    // MARK: - LOS RAYOS X Y EL MOCHILERO 🎯🔬🎒
    func syncOnlyVencimientosYAhorros(context: ModelContext) {
        DispatchQueue.main.async { self.isSyncing = true }
        self.addLog("🎯 [FRANCOTIRADOR] Buscando...")

        let database = (self.connectionStatus == "Invitado") ? container.sharedCloudDatabase : container.privateCloudDatabase
        
        let runFetchChanges = { (zoneToSearch: CKRecordZone.ID?) in
            guard let zID = zoneToSearch else { return }
            
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = nil
            
            let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zID], configurationsByRecordZoneID: [zID: config])
            
            operation.recordWasChangedBlock = { recordID, result in
                if case .success(let record) = result {
                    let type = record.recordType
                    if type.contains("FixedCost") || type.contains("SavingGoal") {
                        DispatchQueue.main.async {
                            self.processAndSaveSingleRecord(record, context: context)
                        }
                    }
                }
            }
            
            operation.fetchRecordZoneChangesResultBlock = { result in
                DispatchQueue.main.async {
                    try? context.save()
                    self.isSyncing = false
                    self.addLog("✅ Escaneo y Descarga de Tickets Ok.")
                }
            }
            database.add(operation)
        }
        
        if self.connectionStatus == "Invitado" {
            database.fetchAllRecordZones { zones, error in
                if let zones = zones, !zones.isEmpty {
                    for zone in zones { runFetchChanges(zone.zoneID) }
                } else {
                    DispatchQueue.main.async { self.isSyncing = false }
                }
            }
        } else {
            let defaultZone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
            runFetchChanges(defaultZone)
        }
    }

    func processAndSaveSingleRecord(_ record: CKRecord, context: ModelContext) {
        let type = record.recordType
        var familyLedger: FamilyLedger?
        let ledgerDescriptor = FetchDescriptor<FamilyLedger>()
        if let results = try? context.fetch(ledgerDescriptor), let existing = results.first {
            familyLedger = existing
        } else {
            let newLedger = FamilyLedger()
            context.insert(newLedger)
            familyLedger = newLedger
        }
        
        if type.contains("FixedCost") {
            let title = record["CD_title"] as? String ?? "Sin nombre"
            let amount = record["CD_amount"] as? Double ?? 0.0
            let dueDay = record["CD_dueDay"] as? Int ?? 10
            let lastPaid = record["CD_lastPaidPeriod"] as? String
            let paidBy = record["CD_paidByWho"] as? String
            
            let descriptor = FetchDescriptor<FixedCost>(predicate: #Predicate<FixedCost> { $0.title == title })
            if let existingCost = (try? context.fetch(descriptor))?.first {
                existingCost.amount = amount
                existingCost.dueDay = dueDay
                existingCost.lastPaidPeriod = lastPaid
                existingCost.paidByWho = paidBy
            } else {
                let newCost = FixedCost(title: title, amount: amount, dueDay: dueDay)
                newCost.ledger = familyLedger
                newCost.lastPaidPeriod = lastPaid
                newCost.paidByWho = paidBy
                context.insert(newCost)
            }
            
        } else if type.contains("SavingGoal") {
            let name = record["CD_name"] as? String ?? "Meta"
            let current = record["CD_currentAmount"] as? Double ?? 0.0
            let target = record["CD_targetAmount"] as? Double ?? 0.0
            let currency = record["CD_currency"] as? String ?? "ARS"
            
            let descriptor = FetchDescriptor<SavingGoal>(predicate: #Predicate<SavingGoal> { $0.name == name })
            
            var targetGoal: SavingGoal?
            if let existingSaving = (try? context.fetch(descriptor))?.first {
                existingSaving.currentAmount = current
                existingSaving.targetAmount = target
                existingSaving.currency = currency
                targetGoal = existingSaving
            } else {
                let newGoal = SavingGoal(name: name, targetAmount: target, currentAmount: current, currency: currency)
                newGoal.ledger = familyLedger
                context.insert(newGoal)
                targetGoal = newGoal
            }
            
            if let historyHack = record["CD_historyHack"] as? String, !historyHack.isEmpty {
                let payloads = historyHack.components(separatedBy: ":::")
                self.addLog("🎒 Desempacando \(payloads.count) tickets para \(name)")
                
                for payload in payloads {
                    let parts = payload.components(separatedBy: "|")
                    if parts.count >= 5 {
                        let timestamp = Double(parts[0]) ?? 0
                        let date = Date(timeIntervalSince1970: timestamp)
                        let mType = parts[1]
                        let mAmount = Double(parts[2]) ?? 0
                        let user = parts[3]
                        let ownerId = parts[4]
                        let note = parts.count > 5 ? parts[5] : ""
                        
                        let movDesc = FetchDescriptor<SavingMovement>()
                        if let allMovs = try? context.fetch(movDesc) {
                            let alreadyExists = allMovs.contains { abs($0.date.timeIntervalSince1970 - timestamp) < 5 && $0.user == user }
                            
                            if !alreadyExists {
                                let newMov = SavingMovement(amount: mAmount, type: mType, user: user, ownerId: ownerId, note: note)
                                newMov.date = date
                                newMov.goal = targetGoal
                                context.insert(newMov)
                                self.addLog("🎟️ Ticket guardado: \(mType) de \(user)")
                            }
                        }
                    }
                }
            } else {
                self.addLog("🎒 Mochila vacía en \(name)")
            }
        }
        try? context.save()
    }
}

// MARK: - VISTA DE CONFIGURACIÓN
struct CloudKitSettingsView: View {
    @ObservedObject var manager = CloudSharingManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var shareURLString = ""

    var body: some View {
        Form {
            Section("Estado de Conexión") {
                HStack {
                    Circle().fill(manager.isSharing ? .green : .red).frame(width: 10)
                    Text(manager.connectionStatus).bold()
                    Spacer()
                    if manager.isSyncing { ProgressView() }
                }
            }
            if !manager.isSharing {
                Section(header: Text("Unirse a Billetera Familiar")) {
                    TextField("Link de iCloud...", text: $shareURLString)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button(action: {
                        manager.acceptShare(from: shareURLString) { _ in shareURLString = "" }
                    }) {
                        HStack { Image(systemName: "link.icloud"); Text("Unirse Manualmente") }
                    }.disabled(shareURLString.isEmpty || manager.isSyncing)
                }
            }
            Section("Monitor en vivo") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(manager.technicalLogs, id: \.self) { log in
                            Text(log).font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(log.contains("✅") || log.contains("🎟️") || log.contains("🎒") ? .green : (log.contains("❌") ? .red : .secondary))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: 250)
            }
        }
        .navigationTitle("Sincronización")
    }
}

// MARK: - COMPONENTE COMPARTIDO NATIVO
struct CloudSharingView: UIViewControllerRepresentable {
    let container: CKContainer
    let share: CKShare

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadWrite]
        controller.modalPresentationStyle = .formSheet
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}
