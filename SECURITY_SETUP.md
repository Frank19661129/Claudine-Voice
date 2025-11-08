# Security Setup - API Keys

## ⚠️ Important Security Update

We've updated Claudine Voice to use environment variables for API keys instead of hardcoding them.

## Setup Instructions

### 1. Create .env file

```bash
cp .env.example .env
```

### 2. Add your API keys to .env

Edit `.env` and add your actual API keys:

```
CLAUDE_API_KEY=sk-ant-api03-YOUR-ACTUAL-KEY-HERE
GOOGLE_TTS_API_KEY=your_google_tts_key_here
```

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run the app

The API keys will now be loaded from `.env` file at startup.

## ✅ Changes Made

- ✅ Added `flutter_dotenv` package to pubspec.yaml
- ✅ Updated `.gitignore` to exclude `.env` file
- ✅ Created `.env.example` template
- ✅ Updated `lib/main.dart` to load from environment
- ✅ Updated `lib/main_mvp.dart` to load from environment
- ✅ Updated `run_mvp.sh` comments

## 🔒 Security

**NEVER commit `.env` to git!**

The `.env` file is in `.gitignore` to prevent accidental commits of API keys.

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
