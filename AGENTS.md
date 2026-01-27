# AGENTS.md

## Repository Overview
- Project: Typo Writer (TW)
- Language/Build: Swift Package Manager (Swift 5.9)
- Platforms: macOS 13+
- Products:
  - CLI executable: `tw` (target: `TypoWriter`)
  - Menubar app: `TypoWriterApp` (target: `TypoWriterApp`)
  - Library: `TypoWriterCore` (target: `Core`)

## External Agent Rules
- Cursor rules:
  - `.cursor/rules/`: none found
  - `.cursorrules`: none found
- Copilot rules:
  - `.github/copilot-instructions.md`: none found

## Build / Run / Test Commands
- Build (debug): `swift build`
- Build (release): `swift build -c release`
- Clean build artifacts: `swift package clean`

- Run CLI (via SPM): `swift run tw --help`
- Run CLI (built binary): `.build/debug/tw --help`
- Release binary path: `.build/release/tw`

- Run all tests: `swift test`
- Run tests with parallelization disabled (sometimes helps debugging): `swift test --parallel false`

### Run a Single Test (important)
SwiftPM test filtering is regex-based. Use the fully-qualified `TestSuite.testMethod` form.
- Run one test method:
  - `swift test --filter CoreTests.testConfigEnvironmentExpansion`
  - `swift test --filter CoreTests.testPromptsGenerationWithCustomPrompt`
- Run all tests in a test case:
  - `swift test --filter CoreTests`
- Handy grep-style filter (regex):
  - `swift test --filter "TWError"`

## Project Layout
- `Package.swift`: SPM manifest (targets/products/dependencies)
- `Sources/Core`: shared library (`TypoWriterCore`)
  - `Sources/Core/AudioRecorder`: AVFoundation recorder
  - `Sources/Core/SpeechRecognition`: ASR abstraction + implementations
  - `Sources/Core/TextProcessor`: LLM text processing
  - `Sources/Core/Config`: YAML config loading + env expansion
  - `Sources/Core/Models`: domain models + `TWError`
  - `Sources/Core/Debug`: `DebugLogger`
- `Sources/TypoWriter`: CLI entrypoint
- `Sources/TypoWriterApp`: macOS menubar app (AppKit)
- `Tests/CoreTests`: unit tests

## Linting / Formatting Tooling
- No SwiftLint / SwiftFormat configuration found.
- Keep diffs minimal and match the surrounding style (don’t do drive-by reformatting).
- Prefer compiler warnings/errors and unit tests as the primary “lint”.

## Coding Style (Swift)
- Prefer clarity over cleverness; keep functions small and predictable.
- Keep changes localized (avoid large refactors unless requested).
- Use `// MARK: - ...` to separate logical sections (this repo uses it heavily, including Chinese headings).
- Follow Swift API Design Guidelines (labels, naming, readability at call sites).

### Imports
- Put `import` statements at the top of the file.
- One import per line.
- Order:
  1) Apple frameworks (e.g. `Foundation`, `AppKit`, `AVFoundation`)
  2) External packages (e.g. `Yams`, `ArgumentParser`)
  3) `@testable import ...` only in tests
- Avoid unused imports.

### Formatting
- Indentation: 4 spaces.
- Braces: K&R style (`if {` on same line).
- Insert blank lines between logical blocks.
- When wrapping arguments, align them vertically.
- Keep line length reasonable; wrap long string literals when needed.

### Types, Access Control, and API Surface
- Use `struct` for value types; use `class` for shared mutable state/singletons (e.g. `DebugLogger`).
- Mark library API explicitly (`public`) where needed; keep helpers `private` / `fileprivate`.
- Prefer immutable `let` properties; only use `var` when mutation is required.
- Provide explicit initializers for public models (common pattern in `Sources/Core/Models`).

### Naming Conventions
- Types: `UpperCamelCase`.
- Methods/vars: `lowerCamelCase`.
- Boolean names read as predicates: `isEnabled`, `hasValue`, `shouldRetry`.
- Avoid single-letter names except in short loops.
- Use descriptive external parameter labels.

### Error Handling
- Use `TWError` for user-facing/core domain errors (`Sources/Core/Models/Models.swift`).
- Prefer `guard` + early `throw` for validation.
- Wrap parsing/IO/network errors with context (keep the original `localizedDescription`).
- For user-visible strings, rely on `TWError: LocalizedError` via `errorDescription`.

### Concurrency
- Use `async/await` for asynchronous operations.
- Keep async functions focused; avoid blocking the main thread (especially in `TypoWriterApp`).

### Networking
- Use `URLSession.shared.data(for:)`.
- Validate URLs and check HTTP status codes.
- Set headers explicitly; do not log secrets.
- Encode request bodies with `JSONEncoder`; decode with `JSONDecoder`.

### Configuration
- Default YAML config path: `~/.config/tw/config.yaml`.
- Config supports env expansion `${VAR_NAME}` (see `ConfigLoader`).
- Keep generated/config files under `~/.config/tw` (don’t write outside the user home dir).

### Logging / Debugging
- Use `DebugLogger` for text-processing/selection debugging.
- Never log API keys/tokens or other secrets.

## Testing Guidelines
- Tests live under `Tests/CoreTests`.
- Test names use `test<Behavior>`.
- Prefer deterministic unit tests; avoid network calls.
- Use `XCTAssert*` APIs for assertions.

## UI/App Notes (TypoWriterApp)
- Stick to existing AppKit patterns and project structure.
- Keep UI orchestration in helper classes (e.g. `MenuBarController`, `HotkeyManager`).
- Keep business logic in `Core`; avoid pulling UI dependencies into `Sources/Core`.

## TODO
- 配置项：支持更多模型提供厂商；将各厂商的模型配置封装为预定义模板，用户只需提供对应 `api_key` 即可。
- 用户预定义词典：在配置文件中支持高频词列表；在语音识别与文本改写时注入词典/提示，提升效果。
- 自定义语气改写：支持用户定义一种“改写方法/语气”并内置为 rewrite preset，供后续快速调用。

## When Unsure
- Look for similar patterns under `Sources/Core` and mirror them.
- Prefer minimal, incremental changes over broad rewrites.
- Ask before changing public API shapes or behavior.
