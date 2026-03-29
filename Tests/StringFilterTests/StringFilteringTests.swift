import Foundation
import StringFilter
import Testing

struct StringFilteringTests {
    @Test("maxLength truncates by Character count")
    func truncatesByCharacterCount() {
        let result = StringFiltering.apply(
            "👩🏽‍💻ABCD",
            options: .init(maxLength: 2)
        )

        #expect(result == "👩🏽‍💻A")
    }

    @Test("width normalization converts in both directions")
    func normalizesWidth() {
        let toHalfWidth = StringFiltering.apply(
            "ＡＢＣ１２３",
            options: .init(width: .toHalfWidth)
        )
        let toFullWidth = StringFiltering.apply(
            "ABC123",
            options: .init(width: .toFullWidth)
        )

        #expect(toHalfWidth == "ABC123")
        #expect(toFullWidth == "ＡＢＣ１２３")
    }

    @Test("letterCase normalizes letters")
    func normalizesLetterCase() {
        let uppercased = StringFiltering.apply(
            "ab12cd",
            options: .init(letterCase: .uppercased)
        )
        let lowercased = StringFiltering.apply(
            "AB12CD",
            options: .init(letterCase: .lowercased)
        )

        #expect(uppercased == "AB12CD")
        #expect(lowercased == "ab12cd")
    }

    @Test("content presets keep only the intended characters")
    func filtersByContentPreset() {
        let letters = StringFiltering.apply(
            "Ab12_-",
            options: .init(content: .asciiLetters)
        )
        let digits = StringFiltering.apply(
            "A1２3B",
            options: .init(content: .decimalDigits)
        )
        let alphanumerics = StringFiltering.apply(
            "A1_-2B!",
            options: .init(content: .asciiAlphanumerics)
        )

        #expect(letters == "Ab")
        #expect(digits == "13")
        #expect(alphanumerics == "A12B")
    }

    @Test("including extends a restricted content preset")
    func includingExtendsRestrictedContent() {
        let result = StringFiltering.apply(
            "ab_cd-12!",
            options: .init(
                content: .asciiAlphanumerics,
                including: CharacterSet(charactersIn: "_-")
            )
        )

        #expect(result == "ab_cd-12")
    }

    @Test("excluding wins over other allow rules")
    func excludingWinsOverAllowedCharacters() {
        let result = StringFiltering.apply(
            "A_B-C",
            options: .init(
                content: .asciiAlphanumerics,
                including: CharacterSet(charactersIn: "_-"),
                excluding: CharacterSet(charactersIn: "_")
            )
        )

        #expect(result == "AB-C")
    }

    @Test("rule order keeps width normalization before content filtering")
    func appliesRulesInDocumentedOrder() {
        let result = StringFiltering.apply(
            "ＡＢ１２!",
            options: .init(
                width: .toHalfWidth,
                content: .asciiAlphanumerics
            )
        )

        #expect(result == "AB12")
    }

    @Test("applying the same options twice is idempotent")
    func isIdempotent() {
        let options = StringFilterOptions(
            maxLength: 8,
            width: .toHalfWidth,
            letterCase: .uppercased,
            content: .asciiAlphanumerics,
            including: CharacterSet(charactersIn: "_-"),
            excluding: CharacterSet.whitespacesAndNewlines
        )

        let once = StringFiltering.apply(" ａｂ_cd-12! \n", options: options)
        let twice = StringFiltering.apply(once, options: options)

        #expect(once == "AB_CD-12")
        #expect(twice == once)
    }
}
