import Foundation
import StringFilter
import Testing

struct StringFilterUsageTests {
    struct Profile {
        @StringFilter(
            maxLength: 8,
            width: .toHalfWidth,
            letterCase: .uppercased,
            content: .asciiAlphanumerics,
            including: CharacterSet(charactersIn: "_-")
        )
        var inviteCode: String = ""
    }

    struct Defaults {
        @StringFilter(
            width: .toHalfWidth,
            letterCase: .uppercased,
            content: .asciiAlphanumerics
        )
        var normalizedIdentifier: String = "ａｂ-12"
    }

    struct AccountForm {
        @StringFilter(
            maxLength: 12,
            width: .toHalfWidth,
            content: .asciiAlphanumerics,
            including: CharacterSet(charactersIn: "_-")
        )
        var username: String = ""

        @StringFilter(
            maxLength: 6,
            width: .toHalfWidth,
            content: .decimalDigits
        )
        var otp: String = ""
    }

    struct CustomContent {
        @StringFilter(
            content: .custom(CharacterSet(charactersIn: "ABC123-_"))
        )
        var token: String = ""
    }

    struct Exclusions {
        @StringFilter(
            width: .toHalfWidth,
            content: .asciiAlphanumerics,
            including: CharacterSet(charactersIn: "_-"),
            excluding: CharacterSet(charactersIn: "_")
        )
        var value: String = "ａ_b-12!"
    }

    @Test("macro-backed property normalizes assigned values through the runtime")
    func macroAppliesFilterOnAssignment() {
        var profile = Profile()
        profile.inviteCode = "ａｂ_cd-12!"

        #expect(profile.inviteCode == "AB_CD-12")
    }

    @Test("default values are normalized through the synthesized init accessor")
    func macroAppliesFilterToDefaultValues() {
        let defaults = Defaults()

        #expect(defaults.normalizedIdentifier == "AB12")
    }

    @Test("multiple filtered properties in the same type remain independent")
    func macroSupportsMultiplePropertiesInOneType() {
        var form = AccountForm()
        form.username = "ａｂ_cd-12!"
        form.otp = "１２3a45"

        #expect(form.username == "ab_cd-12")
        #expect(form.otp == "12345")
    }

    @Test("custom content presets work through the macro in a concrete type")
    func macroSupportsCustomContent() {
        var value = CustomContent()
        value.token = "AZ-12_!"

        #expect(value.token == "A-12_")
    }

    @Test("default values also flow through excluding rules")
    func macroAppliesExclusionsToDefaultValues() {
        let value = Exclusions()

        #expect(value.value == "ab-12")
    }
}
