import Foundation
import SwiftSyntax

public struct CodeEntity: Codable {
    public let name: String      // e.g. "MyClass" or "MyClass.myMethod"
    public let kind: String      // e.g. "class", "function", etc.
    public var calls: [String]   // names of functions called

    public init(name: String, kind: String, calls: [String]) {
        self.name = name
        self.kind = kind
        self.calls = calls
    }
}

public final class DependencyCollector: SyntaxVisitor {
    public var entities = [String: CodeEntity]()
    private var currentContext: String?

    public override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let className = node.identifier.text
        entities[className] = CodeEntity(name: className, kind: "class", calls: [])
        return .visitChildren
    }

    public override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let parentClass = node.parent?.as(ClassDeclSyntax.self) else {
            return .visitChildren
        }
        let className = parentClass.identifier.text
        let functionName = node.identifier.text
        let key = "\(className).\(functionName)"

        entities[key] = CodeEntity(name: key, kind: "function", calls: [])
        currentContext = key
        return .visitChildren
    }

    public override func visitPost(_ node: FunctionDeclSyntax) {
        currentContext = nil
    }

    public override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let contextKey = currentContext {
            let calledName = node.calledExpression.description
                .trimmingCharacters(in: .whitespacesAndNewlines)
            entities[contextKey]?.calls.append(calledName)
        }
        return .visitChildren
    }

    public init() {}
}
