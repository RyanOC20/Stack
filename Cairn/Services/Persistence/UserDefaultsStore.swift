import Foundation

struct UserDefaultsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func value<T>(forKey key: String) -> T? {
        defaults.value(forKey: key) as? T
    }

    func setValue<T>(_ value: T, forKey key: String) {
        defaults.setValue(value, forKey: key)
    }
}
