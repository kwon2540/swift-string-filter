# Swift String Filter

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

`String` 값을 선언적으로 필터링하고 정규화하기 위한 라이브러리입니다.

## 개요

`swift-string-filter`는 프로퍼티 수준에서 예측 가능한 문자열 변환을 적용하기 위한 Swift 매크로 라이브러리입니다.

이 패키지는 입력이 규칙을 위반하더라도 실패를 보고하거나 에러를 던지지 않습니다.
대신 할당된 값을 선언된 정책에 맞는 정규화된 형태로 변환합니다.

이런 특성 때문에 입력 정규화가 명시적이고, 결정적이며, 추론 가능해야 하는 도메인 모델이나 기타 상태 기반 시스템에서 유용합니다.

`@StringFilter`를 사용하면 필터링 규칙을 `String` 프로퍼티에 직접 붙일 수 있습니다.

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

매크로는 자동으로 다음을 수행합니다.

- 원본 값을 저장할 backing storage 프로퍼티를 생성합니다
- 원래 저장 프로퍼티를 계산 프로퍼티로 바꿉니다
- setter 내부에서 할당 값을 필터링하고 정규화합니다

## 설계 목표

이 라이브러리는 검증이 아니라 조용한 변환에 초점을 둡니다.

다음과 같은 경우에 적합합니다.

- 전각과 반각 문자를 정규화하고 싶을 때
- 대문자 또는 소문자를 강제하고 싶을 때
- ASCII 문자나 숫자처럼 허용 문자를 제한하고 싶을 때
- 원치 않는 문자를 제거하고 싶을 때
- 최대 길이를 강제하고 싶을 때

다음과 같은 경우에는 적합하지 않습니다.

- 검증 에러를 보여줘야 할 때
- 잘못된 입력을 거부해야 할 때
- 비밀번호 정책 같은 의미적 규칙을 강제해야 할 때
- 최소 길이를 요구해야 할 때
- 제출 가능한 상태와 불가능한 상태를 구분해야 할 때

이런 문제는 검증 레이어에서 다루는 편이 맞습니다.

## 설치

```swift
dependencies: [
    .package(url: "https://github.com/kwon2540/swift-string-filter", from: "0.1.0")
]
```

그다음 타깃에 product를 추가합니다.

```swift
.target(
    name: "YourFeature",
    dependencies: [
        .product(name: "StringFilter", package: "swift-string-filter")
    ]
)
```

## Swift 매크로 사용

`@StringFilter` 매크로를 사용하면 `String` 프로퍼티에 필터링 규칙을 직접 정의할 수 있습니다.

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

개념적으로는 다음과 비슷하게 동작합니다.

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

## 필터 옵션

### `maxLength`

지정된 문자 수를 넘으면 문자열을 잘라냅니다.

```swift
@StringFilter(maxLength: 8)
var code: String = ""
```

```swift
code = "ABCDEFGHIJK"
// "ABCDEFGH"
```

### `width`

전각과 반각 문자 정규화를 제어합니다.

```swift
public enum StringFilterWidth {
    /// 문자 폭을 그대로 유지합니다.
    case preserve

    /// 가능할 경우 전각 라틴 문자, 숫자, 기호를 반각으로 변환합니다.
    case toHalfWidth

    /// 가능할 경우 반각 라틴 문자, 숫자, 기호를 전각으로 변환합니다.
    case toFullWidth
}
```

예시:

```swift
@StringFilter(width: .toHalfWidth)
var value: String = ""
```

```swift
value = "ＡＢＣ１２３"
// "ABC123"
```

### `letterCase`

대소문자 정규화를 제어합니다.

```swift
public enum StringFilterLetterCase {
    /// 대소문자를 변경하지 않습니다.
    case preserve

    /// 문자를 대문자로 변환합니다.
    case uppercased

    /// 문자를 소문자로 변환합니다.
    case lowercased
}
```

예시:

```swift
@StringFilter(letterCase: .uppercased)
var inviteCode: String = ""
```

```swift
inviteCode = "ab12cd"
// "AB12CD"
```

### `content`

기본 제공되는 콘텐츠 프리셋을 적용합니다.

```swift
public enum StringFilterContent {
    /// 다른 규칙에서 제거하지 않는 한 모든 문자를 허용합니다.
    case unrestricted

    /// ASCII 영문자 `A-Z`와 `a-z`만 남깁니다.
    case asciiLetters

    /// 10진수 숫자 `0-9`만 남깁니다.
    case decimalDigits

    /// ASCII 영문자와 숫자만 남깁니다.
    case asciiAlphanumerics

    /// 전달된 `CharacterSet`에 포함된 문자만 남깁니다.
    case custom(CharacterSet)
}
```

예시:

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

선택한 `content` 프리셋 위에 추가 허용 문자를 더합니다.
독립적인 allowlist가 필요하다면 `content: .custom(...)`를 사용하는 편이 맞습니다.

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

최종 결과에서 문자를 제거합니다.

```swift
@StringFilter(excluding: .whitespacesAndNewlines)
var compactValue: String = ""
```

```swift
compactValue = "A B\nC"
// "ABC"
```

## 규칙 조합 순서

결과가 결정적으로 유지되도록 규칙은 고정된 순서로 적용됩니다.

1. `width`
2. `letterCase`
3. `content`
4. `including`
5. `excluding`
6. `maxLength`

이 순서는 중요합니다.

예를 들어 `.asciiAlphanumerics`를 적용하기 전에 전각 문자를 반각으로 바꾸면 `ＡＢ１２` 같은 값이 제거되지 않고 `AB12`가 됩니다.

## 예시

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

`@StringFilter`는 다음과 같은 정규화 규칙에 가장 잘 맞습니다.

- 예측 가능해야 할 때
- 반복 적용해도 같은 결과가 나와야 할 때
- 사용자가 입력 중에도 이해하기 쉬워야 할 때
- 반복해서 적용해도 안전해야 할 때

좋은 후보는 다음과 같습니다.

- 문자 폭 정규화
- 대소문자 정규화
- ID나 코드용 문자 필터링
- 공백이나 줄바꿈 제거
- 길이 제한

다음과 같은 경우는 덜 적합합니다.

- 비밀번호 정책 강제
- 최소 길이 요구
- 사용자에게 보여줄 형식 검증 에러
- 변환보다 실패가 맞는 비즈니스 규칙

## 제약 사항

- `@StringFilter`는 현재 `String` 타입의 stored `var` 프로퍼티만 지원합니다
- 프로퍼티에는 명시적인 `String` 타입 표기와 기본값이 필요합니다
- Optional `String` 프로퍼티는 지원하지 않습니다
- 계산 프로퍼티, property observer, `lazy` 프로퍼티는 지원하지 않습니다
- `including`은 제한된 `content` 프리셋을 확장할 때만 사용합니다. 독립적인 allowlist에는 `content: .custom(...)`를 사용하세요
- 문자 폭 변환은 사용 가능한 Foundation transform에 의존합니다

## Validation 라이브러리와의 비교

Validation 라이브러리는 보통 다음에 답합니다.

- 이 값이 유효한가?
- 왜 실패했는가?
- 어떤 에러를 보여줘야 하는가?

`swift-string-filter`는 다음에 답합니다.

- 저장 전에 이 값을 어떻게 정규화해야 하는가?
- 어떤 문자가 남아야 하는가?
- 이 입력의 안정적인 저장 표현은 무엇인가?

이 두 접근은 서로 대체 관계가 아니라 같은 모델 안에서 함께 쓸 수 있습니다.

## 매크로 확장 모델

`@StringFilter`는 다음을 사용합니다.

- `@attached(peer)`로 private backing storage 프로퍼티를 생성합니다
- `@attached(accessor)`로 `init`, `get`, `set`을 합성합니다

이 구조 덕분에 호출 지점은 깔끔하게 유지하면서도 기본값과 이후 할당 모두 선언된 필터 파이프라인을 통과하게 만들 수 있습니다.

## License

MIT
