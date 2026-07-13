import Foundation
import Combine

enum SortKey: String, CaseIterable, Identifiable {
    case name         = "Nom"
    case dateModified = "Date de modification"
    case size         = "Poids"
    case fileType     = "Type de fichier"
    var id: String { rawValue }
}

enum SortDirection: String {
    case ascending, descending
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private init() { load() }

    // MARK: - Opening behaviour
    @Published var openFullScreenByDefault: Bool = false
    @Published var alwaysFitOnOpen: Bool = true

    // MARK: - Fit options
    @Published var shrinkHorizontal: Bool  = true
    @Published var shrinkVertical: Bool    = true
    @Published var stretchHorizontal: Bool = false
    @Published var stretchVertical: Bool   = false

    // MARK: - UI
    @Published var showStatusBar: Bool = true

    // MARK: - Sort
    @Published var sortKey: SortKey         = .name
    @Published var sortDirection: SortDirection = .ascending
    @Published var includeSubfolders: Bool  = false

    // MARK: - Persist
    private let defaults = UserDefaults.standard

    func load() {
        openFullScreenByDefault = defaults.bool(forKey: "openFullScreen")
        alwaysFitOnOpen         = defaults.object(forKey: "alwaysFit") as? Bool ?? true
        shrinkHorizontal        = defaults.object(forKey: "shrinkH") as? Bool ?? true
        shrinkVertical          = defaults.object(forKey: "shrinkV") as? Bool ?? true
        stretchHorizontal       = defaults.bool(forKey: "stretchH")
        stretchVertical         = defaults.bool(forKey: "stretchV")
        showStatusBar           = defaults.object(forKey: "statusBar") as? Bool ?? true
        includeSubfolders       = defaults.bool(forKey: "subfolders")
        if let raw = defaults.string(forKey: "sortKey"), let k = SortKey(rawValue: raw) { sortKey = k }
        if let raw = defaults.string(forKey: "sortDir"), let d = SortDirection(rawValue: raw) { sortDirection = d }
    }

    func save() {
        defaults.set(openFullScreenByDefault, forKey: "openFullScreen")
        defaults.set(alwaysFitOnOpen,         forKey: "alwaysFit")
        defaults.set(shrinkHorizontal,        forKey: "shrinkH")
        defaults.set(shrinkVertical,          forKey: "shrinkV")
        defaults.set(stretchHorizontal,       forKey: "stretchH")
        defaults.set(stretchVertical,         forKey: "stretchV")
        defaults.set(showStatusBar,           forKey: "statusBar")
        defaults.set(includeSubfolders,       forKey: "subfolders")
        defaults.set(sortKey.rawValue,        forKey: "sortKey")
        defaults.set(sortDirection.rawValue,  forKey: "sortDir")
    }
}
