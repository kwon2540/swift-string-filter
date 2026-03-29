# Swift String Filter

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

A library for filtering and normalizing `String` values in a declarative manner.

## Overview

`swift-string-filter` is a Swift Macro library for applying predictable string mutations at the property level.

Unlike validation libraries, this package does not report failures or throw errors when input violates a rule.
Instead, it transforms the assigned value into a normalized form that matches the declared policy.

This makes it useful in domain models and other state-driven systems where input normalization should remain explicit, deterministic, and easy to reason about.

With `@StringFilter`, you can attach filtering rules directly to `String` properties:

```swift
import Foundation
import StringFilter

struct SignUpState {
    @StringFilter(
        maxLength: 20,
        width: .toHalfWidth,
        content: .asciiAlphanumerics,
        including: CharacterSet(charactersIn: "_-")
    )
    var username: String = ""

    @StringFilter(
        maxLength: 8,
        width: .toHalfWidth,
        letterCase: .uppercased,
        content: .asciiAlphanumerics
    )
    var inviteCode: String = ""

    @StringFilter(
        maxLength: 30,
        excluding: .newlines
    )
    var nickname: String = ""
}
```

The macro approach automatically:

- Creates a backing storage property for the original value
- Replaces the original stored property with a computed property
- Filters and normalizes the assigned value inside the setter

## Design Goals

This library focuses on silent mutation, not validation.

Use this package when you want to:

- Normalize full-width and half-width characters
- Force uppercase or lowercase values
- Restrict allowed content such as ASCII letters or digits
- Remove unwanted characters
- Enforce a maximum length

Do not use this package when you want to:

- Show validation errors
- Reject invalid input
- Enforce semantic rules such as password policies
- Require a minimum length
- Distinguish valid versus invalid submission state

Those concerns belong in a validation layer.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/kwon2540/swift-string-filter", from: "0.1.0")
]
```

Then add the product to your target:

```swift
.target(
    name: "YourFeature",
    dependencies: [
        .product(name: "StringFilter", package: "swift-string-filter")
    ]
)
```

## Using Swift Macros

You can define filtering rules directly on `String` properties using the `@StringFilter` macro:

```swift
import Foundation
import StringFilter

struct UserProfile {
    @StringFilter(
        maxLength: 10,
        width: .toHalfWidth
    )
    var nickname: String = ""
}
```

This behaves conceptually like:

```swift
struct UserProfile {
    private var _nickname: String

    var nickname: String {
        @storageRestrictions(initializes: _nickname)
        init(initialValue) {
            _nickname = StringFiltering.apply(
                initialValue,
                options: .init(
                    maxLength: 10,
                    width: .toHalfWidth,
                    letterCase: .preserve,
                    content: .unrestricted,
                    including: nil,
                    excluding: nil
                )
            )
        }
        get { _nickname }
        set {
            _nickname = StringFiltering.apply(
                newValue,
                options: .init(
                    maxLength: 10,
                    width: .toHalfWidth,
                    letterCase: .preserve,
                    content: .unrestricted,
                    including: nil,
                    excluding: nil
                )
            )
        }
    }
}
```

## Filter Options

### `maxLength`

Truncates the string when it exceeds the specified character count.

```swift
@StringFilter(maxLength: 8)
var code: String = ""
```

```swift
code = "ABCDEFGHIJK"
// "ABCDEFGH"
```

### `width`

Controls width normalization for full-width and half-width characters.

```swift
public enum StringFilterWidth {
    /// Leaves character width unchanged.
    case preserve

    /// Converts full-width Latin letters, digits, and symbols to half-width forms when possible.
    case toHalfWidth

    /// Converts half-width Latin letters, digits, and symbols to full-width forms when possible.
    case toFullWidth
}
```

Example:

```swift
@StringFilter(width: .toHalfWidth)
var value: String = ""
```

```swift
value = "ＡＢＣ１２３"
// "ABC123"
```

### `letterCase`

Controls case normalization.

```swift
public enum StringFilterLetterCase {
    /// Leaves letter casing unchanged.
    case preserve

    /// Converts letters to uppercase.
    case uppercased

    /// Converts letters to lowercase.
    case lowercased
}
```

Example:

```swift
@StringFilter(letterCase: .uppercased)
var inviteCode: String = ""
```

```swift
inviteCode = "ab12cd"
// "AB12CD"
```

### `content`

Applies a built-in content preset.

```swift
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
```

Examples:

```swift
@StringFilter(content: .decimalDigits)
var otp: String = ""
```

```swift
otp = "12a34"
// "1234"
```

```swift
@StringFilter(content: .asciiLetters)
var initials: String = ""
```

```swift
initials = "A1b-"
// "Ab"
```

```swift
@StringFilter(content: .asciiAlphanumerics)
var username: String = ""
```

```swift
username = "ab-12_!"
// "ab12"
```

```swift
@StringFilter(content: .custom(CharacterSet(charactersIn: "ABC123-_")))
var token: String = ""
```

```swift
token = "AZ-12_!"
// "A-12_"
```

### `including`

Adds extra allowed characters on top of the selected `content` preset.
If you need a standalone allowlist, prefer `content: .custom(...)`.

```swift
@StringFilter(
    content: .asciiAlphanumerics,
    including: CharacterSet(charactersIn: "_-")
)
var username: String = ""
```

```swift
username = "ab_cd-12!"
// "ab_cd-12"
```

### `excluding`

Removes characters from the final result.

```swift
@StringFilter(excluding: .whitespacesAndNewlines)
var compactValue: String = ""
```

```swift
compactValue = "A B\nC"
// "ABC"
```

## Rule Composition

Rules are applied in a fixed order so the result stays deterministic:

1. `width`
2. `letterCase`
3. `content`
4. `including`
5. `excluding`
6. `maxLength`

This order matters.

For example, converting full-width text to half-width before applying `.asciiAlphanumerics` allows values such as `ＡＢ１２` to become `AB12` instead of being removed.

## Examples

### Username

```swift
struct Account {
    @StringFilter(
        maxLength: 20,
        width: .toHalfWidth,
        content: .asciiAlphanumerics,
        including: CharacterSet(charactersIn: "_-")
    )
    var username: String = ""
}
```

```swift
var account = Account()
account.username = "ａｂ_cd-12!"
// "ab_cd-12"
```

### Invite Code

```swift
struct Invite {
    @StringFilter(
        maxLength: 8,
        width: .toHalfWidth,
        letterCase: .uppercased,
        content: .asciiAlphanumerics
    )
    var code: String = ""
}
```

```swift
var invite = Invite()
invite.code = "ab12cd!!"
// "AB12CD"
```

### Numeric Input

```swift
struct Verification {
    @StringFilter(
        maxLength: 6,
        width: .toHalfWidth,
        content: .decimalDigits
    )
    var otp: String = ""
}
```

```swift
var verification = Verification()
verification.otp = "１２3a45"
// "12345"
```

### Free-Form Nickname

```swift
struct Profile {
    @StringFilter(
        maxLength: 30,
        excluding: .newlines
    )
    var nickname: String = ""
}
```

```swift
var profile = Profile()
profile.nickname = "Jun\nHyeok"
// "JunHyeok"
```

## Best Practices

`@StringFilter` works best for normalization rules that are:

- Predictable
- Idempotent
- Easy for users to understand while typing
- Safe to apply repeatedly

Good candidates include:

- Width normalization
- Case normalization
- Character filtering for IDs or codes
- Removing whitespace or newlines
- Length truncation

Less suitable use cases include:

- Password policy enforcement
- Minimum length requirements
- Format validation with user-facing errors
- Business rules that should fail instead of mutate

## Limitations

- `@StringFilter` currently targets stored `var` properties of type `String`
- The property must have an explicit `String` type annotation and a default value
- Optional `String` properties are not supported
- Computed properties, property observers, and `lazy` properties are not supported
- `including` only extends a restricted `content` preset; use `content: .custom(...)` for a standalone allowlist
- Width conversion depends on available Foundation transforms

## Comparison to Validation Libraries

Validation libraries answer:

- Is this value valid?
- Why did it fail?
- What error should be shown?

`swift-string-filter` answers:

- How should this value be normalized before it is stored?
- Which characters should remain?
- What is the stable stored representation of this input?

These two approaches complement each other and can be used together in the same model.

## Macro Expansion Model

`@StringFilter` uses:

- `@attached(peer)` to generate a private backing storage property
- `@attached(accessor)` to synthesize `init`, `get`, and `set`

This allows the original property to keep a clean call site while ensuring both the default value and later assignments pass through the declared filtering pipeline.

## License

MIT
