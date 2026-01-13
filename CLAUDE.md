# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
swift build              # Build debug version
swift build -c release   # Build release version
swift test               # Run all tests
swift test --filter CoreTests.testPromptsGeneration  # Run single test
```

The CLI executable is located at `.build/debug/tw` after building.

## Architecture

Typo Writer (TW) is a smart voice input tool that converts speech to refined text. It's built as a Swift Package with two main products:

- **tw**: CLI executable for end users
- **TypoWriterCore**: Reusable library (designed for future GUI/iOS apps)

### Core Module Structure

The `Sources/Core/` module contains the core logic, designed to be platform-agnostic and reusable:

- **AudioRecorder/**: Microphone recording using AVFoundation, outputs WAV at 16kHz
- **SpeechRecognition/**: ASR abstraction layer with `SpeechRecognizing` protocol
  - Currently implements Aliyun Bailian (qwen3-asr-flash) via HTTP API with Base64 audio
- **TextProcessor/**: LLM text processing with `TextProcessing` protocol
  - Uses OpenAI-compatible API format (works with OpenAI, Claude, DeepSeek, Ollama, etc.)
  - Prompt templates in `Prompts.swift`
- **Config/**: YAML config loading with environment variable expansion (`${VAR_NAME}` syntax)
- **Models/**: Shared data types (`TranscriptionResult`, `ProcessedResult`, `FullProcessingResult`, `TWError`)

### Data Flow

1. `AudioRecorder` captures audio → WAV data
2. `SpeechRecognizer` converts audio → raw transcription text
3. `TextProcessor` refines text via LLM → cleaned output with smart formatting

### Configuration

Config file location: `~/.config/tw/config.yaml`

Key configuration sections:
- `speech_recognition`: ASR provider and credentials
- `text_processing`: LLM endpoint (OpenAI-compatible format), model selection
- `processing`: Output preferences (preserve_style, etc.)
