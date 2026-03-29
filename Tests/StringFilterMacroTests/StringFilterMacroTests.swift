import XCTest

#if os(macOS)
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import StringFilterMacros

private let testMacros: [String: Macro.Type] = [
    "StringFilter": StringFilterMacro.self,
]

final class StringFilterMacroTests: XCTestCase {
    func testMinimalExpansion() throws {
        assertMacroExpansion(
            """
            struct Example {
                @StringFilter(maxLength: 8)
                var code: String = ""
            }
            """,
            expandedSource: """
            struct Example {
                var code: String {
                    @storageRestrictions(initializes: _code)
                    init(initialValue) {
                        _code = StringFiltering.apply(
                            initialValue,
                            options: StringFilterOptions(maxLength: 8, width: .preserve, letterCase: .preserve, content: .unrestricted, including: nil, excluding: nil)
                        )
                    }
                    get {
                        _code
                    }
                    set {
                        _code = StringFiltering.apply(
                            newValue,
                            options: StringFilterOptions(maxLength: 8, width: .preserve, letterCase: .preserve, content: .unrestricted, including: nil, excluding: nil)
                        )
                    }
                }

                private var _code: String
            }
            """,
            macros: testMacros
        )
    }

    func testComposedExpansion() throws {
        assertMacroExpansion(
            """
            struct Example {
                @StringFilter(
                    width: .toHalfWidth,
                    content: .asciiAlphanumerics,
                    including: CharacterSet(charactersIn: "_-"),
                    excluding: .newlines
                )
                var username: String = ""
            }
            """,
            expandedSource: """
            struct Example {
                var username: String {
                    @storageRestrictions(initializes: _username)
                    init(initialValue) {
                        _username = StringFiltering.apply(
                            initialValue,
                            options: StringFilterOptions(maxLength: nil, width: .toHalfWidth, letterCase: .preserve, content: .asciiAlphanumerics, including: CharacterSet(charactersIn: "_-"), excluding: .newlines)
                        )
                    }
                    get {
                        _username
                    }
                    set {
                        _username = StringFiltering.apply(
                            newValue,
                            options: StringFilterOptions(maxLength: nil, width: .toHalfWidth, letterCase: .preserve, content: .asciiAlphanumerics, including: CharacterSet(charactersIn: "_-"), excluding: .newlines)
                        )
                    }
                }

                private var _username: String
            }
            """,
            macros: testMacros
        )
    }

    func testRejectsNonStringProperties() throws {
        assertMacroExpansion(
            """
            struct Example {
                @StringFilter
                var count: Int = 0
            }
            """,
            expandedSource: """
            struct Example {
                var count: Int = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@StringFilter can only be applied to properties of type `String`.", line: 2, column: 5),
            ],
            macros: testMacros
        )
    }

    func testRejectsMissingInitializer() throws {
        assertMacroExpansion(
            """
            struct Example {
                @StringFilter
                var username: String
            }
            """,
            expandedSource: """
            struct Example {
                var username: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@StringFilter requires a default `String` value.", line: 2, column: 5),
            ],
            macros: testMacros
        )
    }

    func testRejectsLetProperties() throws {
        assertMacroExpansion(
            """
            struct Example {
                @StringFilter
                let username: String = ""
            }
            """,
            expandedSource: """
            struct Example {
                let username: String = ""
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@StringFilter can only be applied to stored `var` properties.", line: 2, column: 5),
            ],
            macros: testMacros
        )
    }

    func testRejectsComputedProperties() throws {
        assertMacroExpansion(
            """
            struct Example {
                @StringFilter
                var username: String {
                    ""
                }
            }
            """,
            expandedSource: """
            struct Example {
                var username: String {
                    ""
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@StringFilter does not support computed properties or property observers.", line: 2, column: 5),
            ],
            macros: testMacros
        )
    }

    func testRejectsUnrestrictedIncludingCombination() throws {
        assertMacroExpansion(
            """
            struct Example {
                @StringFilter(including: CharacterSet(charactersIn: "_"))
                var username: String = ""
            }
            """,
            expandedSource: """
            struct Example {
                var username: String = ""
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "`including` only extends a restricted `content` preset. Use `content: .custom(...)` for a standalone allowlist.", line: 2, column: 5),
            ],
            macros: testMacros
        )
    }
}
#else
final class StringFilterMacroTests: XCTestCase {
    func testMacroTestsRequireHostPlatform() throws {
        throw XCTSkip("Macro implementation and macro expansion tests must run with the 'My Mac' destination in Xcode.")
    }
}
#endif
