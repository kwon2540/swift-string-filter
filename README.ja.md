# Swift String Filter

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

`String` 値を宣言的にフィルタリングし、正規化するためのライブラリです。

## 概要

`swift-string-filter` は、プロパティ単位で予測可能な文字列変換を適用するための Swift マクロライブラリです。

このパッケージは、入力がルールに違反していても失敗を報告したりエラーを投げたりしません。
代わりに、代入された値を宣言されたポリシーに合う正規化済みの形へ変換します。

そのため、入力正規化が明示的で、決定的で、追いやすい必要があるドメインモデルやその他の状態駆動システムで有用です。

`@StringFilter` を使うと、フィルタリングルールを `String` プロパティに直接付与できます。

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

このマクロは自動的に次のことを行います。

- 元の値を保持する backing storage プロパティを生成します。
- 元の stored property を computed property に置き換えます。
- setter 内で代入値をフィルタリングし、正規化します。

## 設計目標

このライブラリは、値の正しさを判定することよりも、入力値をその場で整えて保存しやすい形にそろえることに向いています。

次のような場合に向いています。

- 全角と半角を正規化したい
- 大文字または小文字を強制したい
- ASCII 文字や数字のように許可文字を制限したい
- 不要な文字を除去したい
- 最大長を強制したい

次のような場合には向いていません。

- 入力エラーをユーザーに表示したい
- 不正な入力を拒否したい
- パスワードポリシーのような意味的ルールを強制したい
- 最小長を要求したい
- 送信可能かどうかの状態を区別したい

こうした問題は、別の入力チェック層で扱うほうが適しています。

## インストール

```swift
dependencies: [
    .package(url: "https://github.com/kwon2540/swift-string-filter", from: "0.1.0")
]
```

その後、ターゲットに product を追加します。

```swift
.target(
    name: "YourFeature",
    dependencies: [
        .product(name: "StringFilter", package: "swift-string-filter")
    ]
)
```

## Swift マクロの使用

`@StringFilter` マクロを使うと、`String` プロパティにフィルタリングルールを直接定義できます。

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

概念的には次のように動きます。

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

## フィルタオプション

### `maxLength`

指定した文字数を超えた場合に文字列を切り詰めます。

```swift
@StringFilter(maxLength: 8)
var code: String = ""
```

```swift
code = "ABCDEFGHIJK"
// "ABCDEFGH"
```

### `width`

全角と半角の正規化を制御します。

```swift
public enum StringFilterWidth {
    /// 文字をそのまま保ちます。
    case preserve

    /// 可能な場合、全角の英字、数字、記号を半角へ変換します。
    case toHalfWidth

    /// 可能な場合、半角の英字、数字、記号を全角へ変換します。
    case toFullWidth
}
```

例:

```swift
@StringFilter(width: .toHalfWidth)
var value: String = ""
```

```swift
value = "ＡＢＣ１２３"
// "ABC123"
```

### `letterCase`

大文字小文字の正規化を制御します。

```swift
public enum StringFilterLetterCase {
    /// 大文字小文字を変更しません。
    case preserve

    /// 文字を大文字に変換します。
    case uppercased

    /// 文字を小文字に変換します。
    case lowercased
}
```

例:

```swift
@StringFilter(letterCase: .uppercased)
var inviteCode: String = ""

inviteCode = "ab12cd"
// "AB12CD"
```

### `content`

組み込みの content preset を適用します。

```swift
public enum StringFilterContent {
    /// 他のルールで除去されない限り、すべての文字を許可します。
    case unrestricted

    /// ASCII 英字 `A-Z` と `a-z` のみを残します。
    case asciiLetters

    /// 10 進数字 `0-9` のみを残します。
    case decimalDigits

    /// ASCII 英字と数字のみを残します。
    case asciiAlphanumerics

    /// 指定した `CharacterSet` に含まれる文字のみを残します。
    case custom(CharacterSet)
}
```

例:

```swift
@StringFilter(content: .decimalDigits)
var otp: String = ""

otp = "12a34"
// "1234"
```

```swift
@StringFilter(content: .asciiLetters)
var initials: String = ""

initials = "A1b-"
// "Ab"
```

```swift
@StringFilter(content: .asciiAlphanumerics)
var username: String = ""

username = "ab-12_!"
// "ab12"
```

```swift
@StringFilter(content: .custom(CharacterSet(charactersIn: "ABC123-_")))
var token: String = ""

token = "AZ-12_!"
// "A-12_"
```

### `including`

選択した `content` preset に追加の許可文字を足します。
独立した allowlist が必要なら `content: .custom(...)` を使ってください。

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

最終結果から文字を取り除きます。

```swift
@StringFilter(excluding: .whitespacesAndNewlines)
var compactValue: String = ""
```

```swift
compactValue = "A B\nC"
// "ABC"
```

## ルール適用順

結果を決定的に保つため、ルールは固定順で適用されます。

1. `width`
2. `letterCase`
3. `content`
4. `including`
5. `excluding`
6. `maxLength`

この順序は重要です。

たとえば `.asciiAlphanumerics` を適用する前に全角文字を半角へ変換すると、`ＡＢ１２` のような値は削除されず `AB12` になります。

## 例

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

var profile = Profile()
profile.nickname = "Jun\nHyeok"
// "JunHyeok"
```

## Best Practices

`@StringFilter` は次のような正規化ルールに向いています。

- 予測可能であること
- 繰り返し適用しても同じ結果になること
- 入力中でもユーザーにとって理解しやすいこと
- 繰り返し適用しても安全であること

良い候補は次のとおりです。

- 全角/半角の正規化
- 大文字小文字の正規化
- ID やコード向けの文字フィルタリング
- 空白や改行の除去
- 長さ制限

次のような用途にはあまり向きません。

- パスワードポリシーの強制
- 最小長の要求
- ユーザー向けの形式エラー表示
- 変換より失敗が正しいビジネスルール

## 制約事項

- `@StringFilter` は現在 `String` 型の stored `var` プロパティのみを対象とします
- プロパティには明示的な `String` 型注釈とデフォルト値が必要です
- Optional `String` プロパティはサポートしていません
- computed property、property observer、`lazy` プロパティはサポートしていません
- `including` は制限された `content` preset を拡張する用途のみです。独立した allowlist には `content: .custom(...)` を使ってください
- 文字幅変換は利用可能な Foundation transform に依存します

## 入力チェック系ライブラリとの比較

入力チェック系のライブラリは通常、次の問いに答えます。

- この値は妥当か
- なぜ失敗したのか
- どのエラーを表示すべきか

`swift-string-filter` は次の問いに答えます。

- 保存前にこの値をどう正規化すべきか
- どの文字を残すべきか
- この入力の安定した保存表現は何か

この 2 つのアプローチは対立するものではなく、同じモデルの中で併用できます。

## マクロ展開モデル

`@StringFilter` は次を使います。

- `@attached(peer)` で private backing storage プロパティを生成します
- `@attached(accessor)` で `init`、`get`、`set` を合成します

これにより、呼び出し側は簡潔なまま、デフォルト値とその後の代入の両方が宣言したフィルタパイプラインを通るようにできます。

## License

MIT
