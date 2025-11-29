import CoreText
import Foundation

enum FontRegistrar {
    static func registerFonts() {
        let fontFiles = [
            "JetBrainsMono-Regular"
        ]

        for fontFile in fontFiles {
            let url = Bundle.main.url(forResource: fontFile, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: fontFile, withExtension: "ttf")

            guard let url else {
                continue
            }

            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error),
               let error {
                let description = (error.takeRetainedValue() as Error).localizedDescription
                print("Failed to register font \(fontFile): \(description)")
            }
        }
    }
}
