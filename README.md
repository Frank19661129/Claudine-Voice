# Claudine Voice

Voice-controlled personal assistant for Android with calendar integration.

## Features

- 🎤 Voice recognition (Dutch & English)
- 🗣️ Text-to-speech responses
- 📅 Calendar integration (Office 365 & Google Calendar)
- 🤖 AI-powered responses via Claude API
- 📍 Location awareness
- 📱 Offline queue for pending actions

## Version

Current version: **v1.0.0+34**

## Tech Stack

- Flutter/Dart
- FastAPI (Python) backend
- SQLite for local storage
- Claude API for AI responses

## Development

This is the clean voice-only version. The Notes feature is backed up separately for a future release.

### Build

```bash
flutter build apk --release
```

### Primary Location

All development happens in: `D:\dev\Claudine\Claudine-Voice`

## Architecture

- **Frontend**: Flutter app with voice recognition
- **Backend**: Python FastAPI server with calendar integrations
- **Queue Manager**: Offline-first architecture with persistent queue

## Author

Frank - Franklab
