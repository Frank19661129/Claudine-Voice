# Backup - Full Version Files

Deze folder bevat de **volledige versie** van Claudine Voice met wake word detection.

## Waarom hier?

Flutter compileert ALLE Dart files in `lib/`, ook als je `--target=lib/main_mvp.dart` gebruikt.
De volledige versie heeft dependencies (Picovoice) die nog niet klaar zijn.

Dus voor de MVP hebben we deze files tijdelijk hier gezet.

## Wat zit hier?

```
_backup_full_version/
├── main.dart              # Main entry point (volledige versie)
├── config/                # App configuratie
│   └── app_config.dart
├── services/              # Alle services
│   ├── wake_word_service.dart    # Picovoice wake word
│   ├── speech_service.dart       # Speech-to-Text
│   ├── claude_service.dart       # Claude AI
│   ├── tts_service.dart          # Text-to-Speech
│   └── battery_service.dart      # Battery monitoring
└── screens/               # UI screens
    └── home_screen.dart          # Main screen
```

## Later (v1.1+) - Wake Word Toevoegen

Als Picovoice token klaar is:

1. **Update pubspec.yaml**
   ```bash
   cp pubspec.yaml pubspec_mvp.yaml  # Backup current MVP
   # Add back: picovoice_flutter, battery_plus, workmanager
   ```

2. **Restore deze files**
   ```bash
   mv _backup_full_version/* lib/
   ```

3. **Update main.dart**
   - Import wake word service
   - Initialize on startup
   - Add wake word detection logic

4. **Build volledige versie**
   ```bash
   flutter run --target=lib/main.dart
   ```

## Verschil MVP vs Full

| Feature | MVP (nu) | Full (later) |
|---------|----------|-------------|
| Entry point | lib/main_mvp.dart | lib/main.dart |
| Wake word | ❌ Tap to talk | ✅ "Hee Claudine" |
| Background | ❌ Foreground only | ✅ Background listening |
| Architecture | Single file | Modular services |
| Dependencies | Minimal (4) | Complete (15+) |

## Huidige MVP Status

- ✅ Speech-to-Text werkt
- ✅ Claude conversatie werkt
- ✅ Text-to-Speech werkt
- ✅ Visual feedback
- ⏸️ Wake word: wacht op Picovoice token

Focus eerst op MVP testen, dan later wake word toevoegen!
