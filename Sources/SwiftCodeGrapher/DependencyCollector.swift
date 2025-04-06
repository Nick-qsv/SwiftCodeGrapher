import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - Data Structures

/// Holds information about a single top-level entity (class, struct, enum, protocol, or extension).
public struct CodeEntity: Codable {
    public let name: String
    public let kind: String         // e.g. "class", "struct", "protocol", "enum", "extension"
    public var inheritedTypes: [String] = []
    public var conformedProtocols: [String] = []
    public var properties: [PropertyInfo] = []
    public var methods: [MethodInfo] = []
}

/// Holds information about a property (var/let).
public struct PropertyInfo: Codable {
    public let name: String
    public let type: String
}

/// Holds information about a single method/function
public struct MethodInfo: Codable {
    public let name: String
    public let parameters: [ParameterInfo]
    public let returnType: String?
    public var calls: [String]      // which functions it calls internally
}

/// Holds information about a single parameter to a method
public struct ParameterInfo: Codable {
    public let externalName: String?  // If available
    public let internalName: String   // Usually the variable name
    public let type: String?
}

// MARK: - Dependency Collector

public final class DependencyCollector: SyntaxVisitor {
    // Container for all top-level entities (keyed by the entity's name)
    public var entities = [String: CodeEntity]()
    
    // Track current entity name (e.g. "MyClass") when inside it
    private var currentEntityName: String?
    
    // Track current method while visiting a function body
    private var currentMethodIndex: Int?
    
    // We override the default viewMode to sourceAccurate so that we can see everything
    public override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let newEntity = makeEntity(from: node, kind: "class")
        entities[newEntity.name] = newEntity
        currentEntityName = newEntity.name
        
        return .visitChildren
    }
    
    public override func visitPost(_ node: ClassDeclSyntax) {
        currentEntityName = nil
    }
    
    public override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let newEntity = makeEntity(from: node, kind: "struct")
        entities[newEntity.name] = newEntity
        currentEntityName = newEntity.name
        
        return .visitChildren
    }
    
    public override func visitPost(_ node: StructDeclSyntax) {
        currentEntityName = nil
    }
    
    public override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        let newEntity = makeEntity(from: node, kind: "protocol")
        entities[newEntity.name] = newEntity
        currentEntityName = newEntity.name
        
        return .visitChildren
    }
    
    public override func visitPost(_ node: ProtocolDeclSyntax) {
        currentEntityName = nil
    }
    
    public override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let newEntity = makeEntity(from: node, kind: "enum")
        entities[newEntity.name] = newEntity
        currentEntityName = newEntity.name
        
        return .visitChildren
    }
    
    public override func visitPost(_ node: EnumDeclSyntax) {
        currentEntityName = nil
    }
    
    public override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        // For an extension, the extended type's name is in node.extendedType
        // E.g. "extension MyType" => extendedType is MyType
        let extendedTypeName = node.extendedType.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let newEntity = makeEntity(from: node, extendedName: extendedTypeName, kind: "extension")
        entities[newEntity.name] = newEntity
        currentEntityName = newEntity.name
        
        return .visitChildren
    }
    
    public override func visitPost(_ node: ExtensionDeclSyntax) {
        currentEntityName = nil
    }
    
    // MARK: - Visit Variables (Properties)
    // We'll capture properties (var/let) inside the current entity
    public override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let entityName = currentEntityName else {
            return .visitChildren
        }
        
        // The entity must exist in dictionary
        guard var entity = entities[entityName] else {
            return .visitChildren
        }
        
        // variable decl can have multiple PatternBindingSyntax
        // e.g. "var x = 10, y = 20" each is a separate property
        for binding in node.bindings {
            // Attempt to read the pattern name: e.g. "x" from "var x: Int = ..."
            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                let propName = pattern.identifier.text
                // Attempt to read type annotation if present
                var propType: String = "Unknown"
                if let typeAnno = binding.typeAnnotation?.type {
                    propType = typeAnno.description.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                let info = PropertyInfo(name: propName, type: propType)
                entity.properties.append(info)
            }
        }
        
        entities[entityName] = entity
        
        return .visitChildren
    }
    
    // MARK: - Visit Functions (Methods)
    // We'll capture function signature, parameters, return type, etc.
    public override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let entityName = currentEntityName else {
            return .visitChildren
        }
        
        guard var entity = entities[entityName] else {
            return .visitChildren
        }
        
        let funcName = node.name.text
        let (paramList, returnType) = parseParametersAndReturnType(node.signature)
        
        // Create a new MethodInfo
        let method = MethodInfo(
            name: funcName,
            parameters: paramList,
            returnType: returnType,
            calls: []
        )
        
        // Append to entity's methods
        entity.methods.append(method)
        
        // Update storage
        entities[entityName] = entity
        
        // Set current method index so we can add "calls" inside it
        currentMethodIndex = entity.methods.count - 1
        
        return .visitChildren
    }
    
    public override func visitPost(_ node: FunctionDeclSyntax) {
        currentMethodIndex = nil
    }
    
    // MARK: - Visit Function Calls
    public override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let entityName = currentEntityName,
              var entity = entities[entityName],
              let methodIndex = currentMethodIndex else {
            return .visitChildren
        }
        
        // The text of the call expression might look like "playSound" or "player.play()"
        // or "self.something(param: 1)"
        // We'll store the entire calledExpression as a string
        let calledName = node.calledExpression.description
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add to the method's calls
        entity.methods[methodIndex].calls.append(calledName)
        
        // Persist updates
        entities[entityName] = entity
        
        return .visitChildren
    }
    
    // MARK: - Init
    public init() {
        super.init(viewMode: .sourceAccurate)
    }
}

// MARK: - Helpers

/// Create a `CodeEntity` from various syntax nodes that have an inheritance clause
private func makeEntity(from node: DeclSyntaxProtocol, extendedName: String? = nil, kind: String) -> CodeEntity {
    var name = ""
    var inheritedTypes: [String] = []
    var conformedProtocols: [String] = []
    
    if let cl = node.as(ClassDeclSyntax.self) {
        name = cl.name.text
        (inheritedTypes, conformedProtocols) = parseInheritance(cl.inheritanceClause)
    } else if let st = node.as(StructDeclSyntax.self) {
        name = st.name.text
        (inheritedTypes, conformedProtocols) = parseInheritance(st.inheritanceClause)
    } else if let en = node.as(EnumDeclSyntax.self) {
        name = en.name.text
        (inheritedTypes, conformedProtocols) = parseInheritance(en.inheritanceClause)
    } else if let pr = node.as(ProtocolDeclSyntax.self) {
        name = pr.name.text
        (inheritedTypes, conformedProtocols) = parseInheritance(pr.inheritanceClause)
    } else if let ext = node.as(ExtensionDeclSyntax.self) {
        // Extensions do not have an explicit "name" node, so we rely on extendedName:
        name = "Extension_of_\(extendedName ?? "Unknown")"
        (inheritedTypes, conformedProtocols) = parseInheritance(ext.inheritanceClause)
    }
    
    let entity = CodeEntity(
        name: name,
        kind: kind,
        inheritedTypes: inheritedTypes,
        conformedProtocols: conformedProtocols,
        properties: [],
        methods: []
    )
    return entity
}

/// Given something like `: UIViewController, MyProtocol`, separate out class vs. protocols
private func parseInheritance(_ inheritanceClause: InheritanceClauseSyntax?) -> ([String], [String]) {
    guard let inheritanceClause = inheritanceClause else { return ([], []) }
    // In Swift, the first type could be a superclass name, or everything might be protocols
    // We’ll do a simplistic approach: the first is "inherited type" if it’s a class name,
    // the rest we’ll consider protocols. You can refine as you wish.
    
    var inheritedTypes: [String] = []
    var conformedProtocols: [String] = []
    
    for (idx, inheritedType) in inheritanceClause.inheritedTypes.enumerated() {
        let typeName = inheritedType.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if idx == 0 {
            // We’ll tentatively call the first one a base class, but in Swift it could also be a protocol.
            // You can add logic here to check if the symbol is a known class or something else.
            inheritedTypes.append(typeName)
        } else {
            conformedProtocols.append(typeName)
        }
    }
    return (inheritedTypes, conformedProtocols)
}

/// Parse parameters and return type from a function signature.
private func parseParametersAndReturnType(_ signature: FunctionSignatureSyntax) -> ([ParameterInfo], String?) {
    // 1. Parameters
    var params: [ParameterInfo] = []
    
    for param in signature.parameterClause.parameters {
        
        let hasSecondName = param.secondName != nil
        
        // External name only if secondName is present:
        let externalName = hasSecondName
            ? param.firstName.text  // `TokenSyntax` is not optional
            : nil
        
        // Internal name is secondName if present, otherwise firstName.
        let internalName = hasSecondName
            ? param.secondName!.text   // `secondName` is TokenSyntax?
            : param.firstName.text     // fallback
        
        // If `param.type` is a non-optional `TypeSyntax`, just do:
        let typeString = param.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let pInfo = ParameterInfo(
            externalName: externalName,
            internalName: internalName,
            type: typeString.isEmpty ? nil : typeString
        )
        params.append(pInfo)
    }
    
    // 2. Return type
    let returnType = signature.returnClause?.type.description
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    return (params, returnType)
}

