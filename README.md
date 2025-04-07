# SwiftCodeGrapher

## Overview
SwiftCodeGrapher is a command-line tool designed to analyze Swift projects and output a detailed JSON representation of the project's code dependencies. It parses Swift source files to generate a structured graph capturing classes, structs, enums, protocols, extensions, methods, properties, and function calls. This JSON output is ideal for further analysis, visualization, or integration with Large Language Models (LLMs) and other AI-driven tools.

## Features
- **Comprehensive Parsing:** Leverages SwiftSyntax and SwiftParser to accurately analyze Swift source code.
- **Dependency Graph Generation:** Outputs a JSON graph capturing relationships and dependencies across your project's entities.
- **Detailed Analysis:** Captures top-level entities (classes, structs, enums, protocols, extensions), properties, methods, parameters, return types, and internal function calls.
- **Recursive Directory Scanning:** Automatically scans and analyzes all `.swift` files within a given directory and its subdirectories.

## Installation

### Prerequisites
- Swift 6.0 or later
- macOS 13.0 or later

### Building
Clone the repository and build the executable:

```bash
git clone <repository-url>
cd SwiftCodeGrapher
swift build -c release
```

### Usage

```bash
swift run SwiftCodeGrapher <path-to-swift-project>
```

Replace `<path-to-swift-project>` with the absolute or relative path to the Swift project directory you wish to analyze.

### Output
The analysis will generate a `CodeGraph.json` file within your specified project directory. The JSON structure includes:

- **Entities:** Each top-level entity (classes, structs, enums, protocols, extensions).
- **Inherited Types & Protocol Conformance:** Lists base classes and protocols each entity inherits or conforms to.
- **Properties:** Detailed properties including names and types.
- **Methods:** Method signatures, parameters, return types, and internal function calls.

Example JSON snippet:

```json
{
  "MyClass": {
    "name": "MyClass",
    "kind": "class",
    "inheritedTypes": ["UIViewController"],
    "conformedProtocols": ["UITableViewDataSource"],
    "properties": [
      {
        "name": "tableView",
        "type": "UITableView"
      }
    ],
    "methods": [
      {
        "name": "viewDidLoad",
        "parameters": [],
        "returnType": null,
        "calls": [
          "super.viewDidLoad()",
          "setupTableView()"
        ]
      }
    ]
  }
}
```

## Dependencies
- [SwiftSyntax](https://github.com/apple/swift-syntax)
- [SwiftParser](https://github.com/apple/swift-syntax)

## Project Structure
```
SwiftCodeGrapher/
├── Package.swift
├── Sources/
│   └── SwiftCodeGrapher/
│       ├── main.swift
│       └── DependencyCollector.swift
└── Tests/
```

## Customization
You can extend or customize the parsing logic in `DependencyCollector.swift` to handle additional use cases or gather more specific data points from your codebase.

## Use Cases
- Project dependency visualization
- Integration with AI and LLMs for advanced code analysis
- Static analysis and documentation generation
- Continuous integration and automated reviews

## Contributing
Pull requests and contributions are welcome. Please follow Swift coding conventions and ensure comprehensive documentation and testing.

## License
SwiftCodeGrapher is released under the MIT License. See [LICENSE](LICENSE) for details.

