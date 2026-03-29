import Foundation

extension StringFiltering {
    static func normalizeWidth(in value: String, using width: StringFilterWidth) -> String {
        switch width {
        case .preserve:
            value
        case .toHalfWidth:
            value.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? value
        case .toFullWidth:
            value.applyingTransform(.fullwidthToHalfwidth, reverse: true) ?? value
        }
    }

    static func normalizeLetterCase(in value: String, using letterCase: StringFilterLetterCase) -> String {
        switch letterCase {
        case .preserve:
            value
        case .uppercased:
            value.uppercased()
        case .lowercased:
            value.lowercased()
        }
    }

    static func filterByAllowedContent(
        in value: String,
        content: StringFilterContent,
        including: CharacterSet?
    ) -> String {
        guard let allowedScalars = effectiveAllowedScalars(for: content, including: including) else {
            return value
        }

        return String(
            value.filter { character in
                character.unicodeScalars.allSatisfy(allowedScalars.contains)
            }
        )
    }

    static func filterByExclusions(in value: String, excluding: CharacterSet?) -> String {
        guard let excluding else {
            return value
        }

        return String(
            value.filter { character in
                !character.unicodeScalars.contains(where: excluding.contains)
            }
        )
    }

    static func truncate(_ value: String, to maxLength: Int?) -> String {
        guard let maxLength else {
            return value
        }

        guard maxLength > 0 else {
            return ""
        }

        return String(value.prefix(maxLength))
    }

    static func effectiveAllowedScalars(
        for content: StringFilterContent,
        including: CharacterSet?
    ) -> CharacterSet? {
        guard var base = baseAllowedScalars(for: content) else {
            return nil
        }

        if let including {
            base.formUnion(including)
        }

        return base
    }

    static func baseAllowedScalars(for content: StringFilterContent) -> CharacterSet? {
        switch content {
        case .unrestricted:
            nil
        case .asciiLetters:
            .stringFilterASCIIAlphabet
        case .decimalDigits:
            .stringFilterASCIIDigits
        case .asciiAlphanumerics:
            .stringFilterASCIIAlphanumerics
        case let .custom(characterSet):
            characterSet
        }
    }
}

private extension CharacterSet {
    static let stringFilterASCIIAlphabet = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    )

    static let stringFilterASCIIDigits = CharacterSet(charactersIn: "0123456789")

    static let stringFilterASCIIAlphanumerics: CharacterSet = {
        var characterSet = CharacterSet.stringFilterASCIIAlphabet
        characterSet.formUnion(.stringFilterASCIIDigits)
        return characterSet
    }()
}
