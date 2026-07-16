import Foundation
import Combine

enum SortKey: String, CaseIterable, Identifiable {
    case name, dateModified, size, fileType
    var id: String { rawValue }
    var label: String {
        switch self {
        case .name: return L("sort.name")
        case .dateModified: return L("sort.dateModified")
        case .size: return L("sort.size")
        case .fileType: return L("sort.fileType")
        }
    }
}

enum SortDirection: String {
    case ascending, descending
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private init() { load() }

    @Published var language: AppLanguage = .english

    @Published var openFullScreenByDefault: Bool = false
    @Published var alwaysFitOnOpen: Bool = true
    @Published var singleWindowMode: Bool = true

    @Published var shrinkHorizontal: Bool  = true
    @Published var shrinkVertical: Bool    = true
    @Published var stretchHorizontal: Bool = false
    @Published var stretchVertical: Bool   = false

    @Published var showStatusBar: Bool = true

    @Published var sortKey: SortKey         = .name
    @Published var sortDirection: SortDirection = .ascending
    @Published var includeSubfolders: Bool  = false

    private let defaults = UserDefaults.standard

    func load() {
        if let raw = defaults.string(forKey: "language"), let l = AppLanguage(rawValue: raw) {
            language = l
        } else {
            // Default to English regardless of system locale, per product decision.
            language = .english
        }
        openFullScreenByDefault = defaults.bool(forKey: "openFullScreen")
        alwaysFitOnOpen         = defaults.object(forKey: "alwaysFit") as? Bool ?? true
        singleWindowMode        = defaults.object(forKey: "singleWindow") as? Bool ?? true
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
        defaults.set(language.rawValue,       forKey: "language")
        defaults.set(openFullScreenByDefault, forKey: "openFullScreen")
        defaults.set(alwaysFitOnOpen,         forKey: "alwaysFit")
        defaults.set(singleWindowMode,        forKey: "singleWindow")
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
