import Foundation

#if os(macOS)
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct StringFilterMacro: AccessorMacro, PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let property = validate(declaration, attribute: node, in: context, shouldDiagnose: false) else {
            return []
        }

        return [property.backingStorageDecl]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let property = validate(declaration, attribute: node, in: context, shouldDiagnose: true) else {
            return []
        }

        return [
            """
            @storageRestrictions(initializes: \(raw: property.backingStorageIdentifier))
            init(initialValue) {
                \(raw: property.backingStorageIdentifier) = StringFiltering.apply(
                    initialValue,
                    options: \(raw: property.optionsExpression)
                )
            }
            """,
            """
            get {
                \(raw: property.backingStorageIdentifier)
            }
            """,
            """
            set {
                \(raw: property.backingStorageIdentifier) = StringFiltering.apply(
                    newValue,
                    options: \(raw: property.optionsExpression)
                )
            }
            """,
        ]
    }

    private static func validate(
        _ declaration: some DeclSyntaxProtocol,
        attribute: AttributeSyntax,
        in context: some MacroExpansionContext,
        shouldDiagnose: Bool
    ) -> ValidProperty? {
        guard let variable = declaration.as(VariableDeclSyntax.self) else {
            if shouldDiagnose {
                diagnose(
                    "@StringFilter can only be applied to stored `var` properties.",
                    on: attribute,
                    in: context
                )
            }
            return nil
        }

        guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
            if shouldDiagnose {
                diagnose(
                    "@StringFilter can only be applied to stored `var` properties.",
                    on: attribute,
                    in: context
                )
            }
            return nil
        }

        guard variable.bindings.count == 1, let binding = variable.bindings.first else {
            if shouldDiagnose {
                diagnose(
                    "@StringFilter requires a single stored `String` property declaration.",
                    on: attribute,
                    in: context
                )
            }
            return nil
        }

        if variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.lazy) }) {
            if shouldDiagnose {
                diagnose(
                    "@StringFilter does not support `lazy` properties.",
                    on: attribute,
                    in: context
                )
            }
            return nil
        }

        guard binding.accessorBlock == nil else {
            if shouldDiagnose {
                diagnose(
                    "@StringFilter does not support computed properties or property observers.",
                    on: attribute,
                    in: context
                )
            }
            return nil
        }

        guard binding.initializer != nil else {
            if shouldDiagnose {
                diagnose(
                    "@StringFilter requires a default `String` value.",
                    on: attribute,
                    in: context
                )
            }
            return nil
        }

        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
            if shouldDiagnose {
                diagnose(
                    "@StringFilter requires a named stored property.",
                    on: attribute,
                    in: context
                )
            }
            return nil
        }

        guard let typeAnnotation = binding.typeAnnotation else {
            if shouldDiagnose {
                diagnose(
                    "@StringFilter requires an explicit `String` type annotation.",
                    on: attribute,
                    in: context
                )
            }
            return nil
        }

        switch classify(type: typeAnnotation.type) {
        case .string:
            break
        case .optionalString:
            if shouldDiagnose {
                diagnose(
                    "@StringFilter does not support optional `String` properties.",
                    on: attribute,
                    in: context
                )
            }
            return nil
        case .unsupported:
            if shouldDiagnose {
                diagnose(
                    "@StringFilter can only be applied to properties of type `String`.",
                    on: attribute,
                    in: context
                )
            }
            return nil
        }

        let arguments = parseArguments(from: attribute)
        if arguments.usesUnrestrictedContentWithIncluding {
            if shouldDiagnose {
                diagnose(
                    "`including` only extends a restricted `content` preset. Use `content: .custom(...)` for a standalone allowlist.",
                    on: attribute,
                    in: context
                )
            }
            return nil
        }

        let isStatic = variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) })
        let storagePrefix = isStatic ? "private static" : "private"
        let propertyName = identifier.identifier.text
        let backingStorageIdentifier = "_\(propertyName)"

        return ValidProperty(
            backingStorageIdentifier: backingStorageIdentifier,
            backingStorageDecl: "\(raw: storagePrefix) var \(raw: backingStorageIdentifier): String",
            optionsExpression: arguments.optionsExpression
        )
    }

    private static func classify(type: TypeSyntax) -> PropertyType {
        if isStringType(type) {
            return .string
        }

        if isOptionalStringType(type) {
            return .optionalString
        }

        return .unsupported
    }

    private static func isStringType(_ type: TypeSyntax) -> Bool {
        guard let identifier = type.as(IdentifierTypeSyntax.self) else {
            return false
        }

        return identifier.name.text == "String" && identifier.genericArgumentClause == nil
    }

    private static func isOptionalStringType(_ type: TypeSyntax) -> Bool {
        if let optional = type.as(OptionalTypeSyntax.self) {
            return isStringType(optional.wrappedType)
        }

        let normalized = type.trimmedDescription.replacingOccurrences(of: " ", with: "")
        return normalized == "Optional<String>"
    }

    private static func parseArguments(from attribute: AttributeSyntax) -> ParsedArguments {
        let labeledArguments = attribute.arguments?.as(LabeledExprListSyntax.self) ?? []
        var values = [String: String]()

        for argument in labeledArguments {
            guard let label = argument.label?.text else {
                continue
            }

            values[label] = argument.expression.trimmedDescription
        }

        let maxLength = values["maxLength"] ?? "nil"
        let width = values["width"] ?? ".preserve"
        let letterCase = values["letterCase"] ?? ".preserve"
        let content = values["content"] ?? ".unrestricted"
        let including = values["including"] ?? "nil"
        let excluding = values["excluding"] ?? "nil"

        return ParsedArguments(
            usesUnrestrictedContentWithIncluding: isUnrestricted(content) && including != "nil",
            optionsExpression: "StringFilterOptions(maxLength: \(maxLength), width: \(width), letterCase: \(letterCase), content: \(content), including: \(including), excluding: \(excluding))"
        )
    }

    private static func isUnrestricted(_ contentExpression: String) -> Bool {
        let normalized = contentExpression.replacingOccurrences(of: " ", with: "")
        return normalized == ".unrestricted" || normalized.hasSuffix(".unrestricted")
    }

    private static func diagnose(
        _ message: String,
        on node: some SyntaxProtocol,
        in context: some MacroExpansionContext
    ) {
        let diagnostic = Diagnostic(
            node: Syntax(node),
            message: StringFilterDiagnosticMessage(message: message)
        )
        context.diagnose(diagnostic)
    }
}

@main
struct StringFilterPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StringFilterMacro.self,
    ]
}

private struct ValidProperty {
    let backingStorageIdentifier: String
    let backingStorageDecl: DeclSyntax
    let optionsExpression: String
}

private enum PropertyType {
    case string
    case optionalString
    case unsupported
}

private struct ParsedArguments {
    let usesUnrestrictedContentWithIncluding: Bool
    let optionsExpression: String
}

private struct StringFilterDiagnosticMessage: DiagnosticMessage {
    let message: String

    var diagnosticID: MessageID {
        MessageID(domain: "StringFilterMacro", id: message)
    }

    var severity: DiagnosticSeverity {
        .error
    }
}
#endif
