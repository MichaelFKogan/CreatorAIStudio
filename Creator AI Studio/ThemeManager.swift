import SwiftUI

class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool = true // Default to dark mode
    
    init() {
        // Check if user has a saved preference, otherwise default to dark mode
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? true
    }
    
    func toggleTheme() {
        isDarkMode.toggle()
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
    }
    
    var colorScheme: ColorScheme {
        return isDarkMode ? .dark : .light
    }
}
