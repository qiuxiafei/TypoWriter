# PRD 001 - Config Presets v1

## Status
- Version: v1
- Owner: TBD
- Last updated: 2026-01-21

## Background
The project currently exposes low-level configuration fields (e.g. `base_url`, `model`) to users and includes not-yet-implemented providers in code/UI.
This causes:
- Users can select unsupported providers leading to crashes (`fatalError`).
- Config is easy to misconfigure (wrong URL/model).
- Example configs are inconsistent between CLI and app.

## Goals
- Users configure via a preset + API key only (no editing of URL/model).
- V1 presets:
  - Speech (ASR): `dashscope_qwen_asr`
  - Text (LLM): `dashscope_qwen_plus`
- Remove unsupported speech providers from the UI.
- Make schema extensible for future vendors/presets.

## Non-goals
- No support for Ollama/DeepSeek/other compatible services in v1.
- No “advanced override” of URL/model.
- No config migration strategy in v1 (new schema only).

## Terminology
- Preset: A built-in configuration profile with fixed endpoint/model/defaults.
- Credentials: User-provided secrets. V1 only requires `api_key`.

## User-Facing Configuration (YAML)
Use `preset` (not `template`) and keep credentials explicit.

```yaml
speech_recognition:
  preset: dashscope_qwen_asr
  credentials:
    api_key: ${DASHSCOPE_API_KEY}

text_processing:
  preset: dashscope_qwen_plus
  credentials:
    api_key: ${DASHSCOPE_API_KEY}

processing:
  prompt: |
    ...
  rewrite_prompt: |
    ...
```

### Notes
- `credentials.api_key` supports `${ENV_VAR}` expansion.
- Presets own all fixed values (endpoint/model/defaults).

## Preset Definitions (V1)

### Speech Recognition Preset
Preset ID: `dashscope_qwen_asr`
- Vendor: DashScope
- Endpoint (fixed):
  - `https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation`
- Model (fixed): `qwen3-asr-flash`
- Defaults (fixed):
  - `enable_itn = true`
- Credentials required: `api_key`

### Text Processing Preset
Preset ID: `dashscope_qwen_plus`
- Vendor: DashScope (OpenAI-compatible)
- Endpoint (fixed, base_url + path merged):
  - `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`
- Model (fixed): `qwen-plus`
- Defaults (fixed):
  - `temperature = 0.3`
  - `max_tokens = 4096`
- Credentials required: `api_key`

## UI Requirements (macOS App)
Update the config window so users only:
- Select a preset (picker).
- Enter an API key.

### Speech Section
- Preset picker
  - V1 options: `DashScope - Qwen ASR (qwen3-asr-flash)`
- API key field
- Read-only display: endpoint + model
- Remove: provider segmented control, model input

### Text Processing Section
- Preset picker
  - V1 options: `DashScope - Qwen Plus (qwen-plus)`
- API key field
- Read-only display: endpoint + model
- Remove: base URL input, model input

### Prompt Section
- Keep existing behavior (default/custom prompt toggles + editors).

### Validation
- Speech API key required.
- Text API key required.
- No URL/model validation (users cannot edit them).

## Code Interface Design
Keep stable boundaries as protocols.

### Existing Protocols (keep)
- Speech: `SpeechRecognizing`
  - `transcribe(audio: Data) async throws -> TranscriptionResult`
- Text: `TextProcessing`
  - `process(rawText: String, customPrompt: String?) async throws -> ProcessedResult`
  - `rewrite(originalText: String, instruction: String, customPrompt: String?) async throws -> ProcessedResult`

### New Concepts
- Preset Registry: built-in list of presets.
- Resolve step: turn `(presetId, credentials)` into a resolved config used by concrete implementations.

### Suggested Types
- `APICredentials` (v1): `{ apiKey: String }`
- `SpeechRecognitionConfig` (new shape): `{ preset: SpeechPresetID, credentials: APICredentials }`
- `TextProcessingConfig` (new shape): `{ preset: TextPresetID, credentials: APICredentials }`

- `ResolvedSpeechConfig`: `{ endpoint: URL, apiKey: String, model: String, enableItn: Bool }`
- `ResolvedTextConfig`: `{ endpoint: URL, apiKey: String, model: String, temperature: Double, maxTokens: Int }`

### Factory Behavior
- `SpeechRecognizerFactory.create(config:) -> SpeechRecognizing`
  - Resolve preset -> init concrete ASR class.
  - Unknown preset -> throw a readable `TWError` (no `fatalError`).
- `TextProcessorFactory.create(config:) -> TextProcessing`
  - Resolve preset -> init OpenAI-compatible processor with resolved endpoint.

## Out of Scope TODOs
- User dictionary injection.
- Custom rewrite tone/preset system.
