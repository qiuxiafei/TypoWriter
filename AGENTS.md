# AGENTS.md

## Repository Overview
- Project: Typo Writer (TW)
- Language: Swift Package Manager (Swift 5.9)
- Products: CLI `tw`, menubar app `TypoWriterApp` (Typo Writer), library `TypoWriterCore`
- Platforms: macOS 13+
- Core modules live under `Sources/Core`
- UI/app modules live under `Sources/TypoWriterApp`

## Required External Rules
- No Cursor rules found in `.cursor/rules/` or `.cursorrules`
- No Copilot instructions found in `.github/copilot-instructions.md`

## Build / Test Commands
- Build debug: `swift build`
- Build release: `swift build -c release`
- Run all tests: `swift test`
- Run a single test: `swift test --filter CoreTests.testPromptsGeneration`
- CLI executable output: `.build/debug/tw`

## Project Layout
- `Package.swift`: SPM manifest with dependencies

## Linting / Formatting Tools
- No SwiftLint/SwiftFormat config in repo
- Keep formatting consistent with existing code
- Avoid adding new lint/format tools unless requested
- `Sources/Core/AudioRecorder`: AVFoundation recorder
- `Sources/Core/SpeechRecognition`: ASR abstraction + implementations
- `Sources/Core/TextProcessor`: LLM text processing
- `Sources/Core/Config`: YAML config loading
- `Sources/Core/Models`: shared domain models + errors
- `Sources/TypoWriter`: CLI entrypoint
- `Sources/TypoWriterApp`: macOS app
- `Tests/CoreTests`: unit tests for Core

## Code Style Summary
- Prefer clarity over cleverness
- Keep changes minimal and localized
- Use `// MARK: - Section` headings to organize files
- Follow Swift API Design Guidelines

## Imports
- Place `import` statements at the top of the file
- Use one import per line
- Order imports by standard library, then external
- Avoid unused imports

## Formatting
- Indentation uses 4 spaces
- Braces follow K&R style (same line)
- Align wrapped arguments vertically
- Blank line between logical sections
- Keep line length reasonable; wrap long literals

## Types and Access Control
- Use `struct` for value types, `class` for reference types
- Mark public API explicitly with `public`
- Keep internal helpers `private` or `fileprivate`
- Prefer immutable `let` where possible
- Optional properties use `?` with explicit defaults

## Naming Conventions
- Types use `UpperCamelCase`
- Methods and variables use `lowerCamelCase`
- Boolean names read as predicates (`isEnabled`, `hasValue`)
- Avoid single-letter names outside short loops
- Use descriptive parameter labels

## Error Handling
- Use `TWError` for user-facing errors
- Prefer `guard` with early `throw` for validation
- Wrap parsing errors with context when needed
- Surface network failures via `TWError.networkError`
- Provide localized descriptions in `TWError.errorDescription`

## Concurrency
- Async operations use `async/await`
- Network calls use `URLSession.shared.data(for:)`
- Keep async functions small and focused
- Avoid blocking the main thread in app targets

## Networking
- Validate URLs before use
- Set required headers explicitly
- Encode request bodies with `JSONEncoder`
- Decode with `JSONDecoder` and proper key strategies
- Check HTTP status codes and return friendly errors

## Configuration
- YAML config path: `~/.config/tw/config.yaml`
- Environment expansion supports `${VAR_NAME}`
- Validation happens in `ConfigLoader`
- Provide example config via `createExampleConfig`

## Data Models
- Define Codable models close to feature logic
- Keep request/response models `private` within file
- Use explicit `CodingKeys` for snake_case fields
- Prefer optional fields for API responses

## Resources and Paths
- App target excludes `Info.plist` and entitlements from compilation
- Prefer `FileManager` for user path lookups
- Avoid writing outside the user home directory
- Keep generated config under `~/.config/tw`

## Testing Guidelines
- Tests live under `Tests/CoreTests`
- Test names use `test<Behavior>` style
- Use `XCTAssert*` for expectations
- Keep tests deterministic
- Prefer unit tests over integration tests

## Documentation and Comments
- Public types should have short doc comments
- Prefer concise inline comments when necessary
- Avoid redundant comments for otwous logic
- Keep Chinese comments if the surrounding file uses them

## Swift Package Manager Practices
- Add new dependencies in `Package.swift`
- Keep target dependencies explicit
- Prefer internal targets over ad-hoc file references

## UI/App Code
- Use AppKit patterns consistent with existing files
- Keep UI logic out of Core
- Use helper classes (`MenuBarController`, `HotkeyManager`) for orchestration

## Logging and Debugging
- Use `DebugLogger` for text-processing logging
- Do not log secrets (API keys, tokens)

## Preferred Patterns
- Initialize models with explicit initializer
- Validate configs early
- Use `enum` for provider choices
- Keep API models `private` within file

## Avoid
- Do not add new linting tooling
- Do not introduce formatting changes unrelated to task
- Do not add inline comments unless requested
- Do not add new files unless necessary

## When Unsure
- Check similar implementations under `Sources/Core`
- Follow existing formatting and `// MARK:` usage
- Ask for clarification on public API changes
