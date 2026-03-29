import Foundation

/// A property macro that normalizes string assignments according to a declared filtering policy.
@attached(peer, names: prefixed(_))
@attached(accessor, names: named(init), named(get), named(set))
public macro StringFilter(
    maxLength: Int? = nil,
    width: StringFilterWidth = .preserve,
    letterCase: StringFilterLetterCase = .preserve,
    content: StringFilterContent = .unrestricted,
    including: CharacterSet? = nil,
    excluding: CharacterSet? = nil
) = #externalMacro(module: "StringFilterMacros", type: "StringFilterMacro")

/// Controls whether character width should be normalized.
public enum StringFilterWidth {
    /// Leaves character width unchanged.
    case preserve

    /// Converts full-width Latin letters, digits, and symbols to half-width forms when possible.
    case toHalfWidth

    /// Converts half-width Latin letters, digits, and symbols to full-width forms when possible.
    case toFullWidth
}

/// Controls whether alphabetic characters should be case-normalized.
public enum StringFilterLetterCase {
    /// Leaves letter casing unchanged.
    case preserve

    /// Converts letters to uppercase.
    case uppercased

    /// Converts letters to lowercase.
    case lowercased
}

/// Defines the base allowlist applied before additional include and exclude rules.
public enum StringFilterContent {
    /// Allows any character unless removed by other rules.
    case unrestricted

    /// Keeps only ASCII letters `A-Z` and `a-z`.
    case asciiLetters

    /// Keeps only decimal digits `0-9`.
    case decimalDigits

    /// Keeps only ASCII letters and decimal digits.
    case asciiAlphanumerics

    /// Keeps only characters contained in the supplied `CharacterSet`.
    case custom(CharacterSet)
}

/// Collects the full filtering policy for a single normalization pass.
public struct StringFilterOptions {
    /// Maximum number of `Character` values allowed after filtering. `nil` means no limit.
    public var maxLength: Int?

    /// Width normalization policy.
    public var width: StringFilterWidth

    /// Letter case normalization policy.
    public var letterCase: StringFilterLetterCase

    /// Base content allowlist.
    public var content: StringFilterContent

    /// Additional characters allowed on top of `content`.
    public var including: CharacterSet?

    /// Characters to remove after all other allowlist decisions.
    public var excluding: CharacterSet?

    /// Creates a new filtering policy value.
    public init(
        maxLength: Int? = nil,
        width: StringFilterWidth = .preserve,
        letterCase: StringFilterLetterCase = .preserve,
        content: StringFilterContent = .unrestricted,
        including: CharacterSet? = nil,
        excluding: CharacterSet? = nil
    ) {
        self.maxLength = maxLength
        self.width = width
        self.letterCase = letterCase
        self.content = content
        self.including = including
        self.excluding = excluding
    }
}

/// Applies string filtering options in a deterministic order and returns the normalized result.
public enum StringFiltering {
    /// Applies the supplied filtering options in this order:
    /// width, letterCase, content, including, excluding, maxLength.
    public static func apply(_ value: String, options: StringFilterOptions) -> String {
        let widthNormalized = normalizeWidth(in: value, using: options.width)
        let caseNormalized = normalizeLetterCase(in: widthNormalized, using: options.letterCase)
        let contentFiltered = filterByAllowedContent(
            in: caseNormalized,
            content: options.content,
            including: options.including
        )
        let exclusionFiltered = filterByExclusions(in: contentFiltered, excluding: options.excluding)
        return truncate(exclusionFiltered, to: options.maxLength)
    }
}
