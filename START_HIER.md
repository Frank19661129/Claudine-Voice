# 🚀 START HIER - Claudine Voice MVP

## Wat is dit?

**Android voice assistant app** - Tap to talk met Claude AI.

- ✅ Speech-to-Text (Native)
- ✅ Claude conversatie (API key al ingesteld)
- ✅ Text-to-Speech (Nederlands)
- ✅ Visual feedback
- ⏸️ Wake word komt later (als Picovoice token er is)

## Quick Start (2 stappen)

### 1. Android Device Klaar?

**Optie A: Android Phone**
```
Phone → Settings → Developer Options → USB Debugging [ON]
Connect USB cable
```

**Optie B: Emulator**
```bash
flutter emulators
flutter emulators --launch <naam>
```

### 2. Run!

**Windows:**
```cmd
cd "C:\Users\frank\OneDrive - Madano BV\Lab\Claudine\Claudine-Voice"
run_mvp.bat
```

**Linux/Mac:**
```bash
cd ~/franklab/claudine/Claudine-Voice
./run_mvp.sh
```

**Done!** App build + installeert + start.

## Gebruik

```
1. App opent → Allow microphone
2. Blauw scherm → Tap grote mic button
3. Paars scherm → Spreek je vraag
4. Oranje → Claude denkt
5. Groen → Claudine antwoordt (voice)
6. Terug naar blauw → Klaar voor volgende
```

## Test Conversatie

```
You: "Hallo"
Claudine: "Hallo! Hoe kan ik je helpen?"

You: "Herinner me aan melk kopen"
Claudine: "Natuurlijk! Wanneer wil je dat ik je herinner?"

You: "Rond 18 uur"
Claudine: "Oké, ik zet een reminder voor vandaag 18:00."
```

## Files Overview

```
📂 Claudine-Voice/
├─ 📖 START_HIER.md           ← JIJ BENT HIER
├─ 📖 README_MVP.md            ← Uitgebreide docs
├─ 📋 CHECKLIST.md             ← Test checklist
│
├─ 🚀 run_mvp.bat              ← RUN DIT (Windows)
├─ 🚀 run_mvp.ps1              ← Of dit (PowerShell)
├─ 🚀 run_mvp.sh               ← Linux/Mac versie
│
├─ 📱 lib/
│  └─ main_mvp.dart            ← Complete MVP (1 file)
│
├─ ⚙️ pubspec_mvp.yaml         ← Dependencies
├─ 🤖 android/                 ← Android config
│  └─ app/
│     ├─ build.gradle
│     └─ src/main/AndroidManifest.xml
│
└─ 🔮 Later (vol v1.0):
   ├─ lib/services/            ← Wake word, battery, etc
   └─ lib/screens/             ← Full UI

MVP = lib/main_mvp.dart (everything in 1 file)
```

## Stack (Same as FrankScan)

- **Framework**: Flutter 3.9.2+
- **State**: Riverpod
- **Platform**: Android (iOS later)
- **Voice**: Native STT/TTS
- **AI**: Claude 3.5 Sonnet

## API Keys

- ✅ **Claude**: Already in code (line 25 of main_mvp.dart)
- ⏸️ **Picovoice**: Komt later (voor wake word)

## Troubleshooting

### "No Android device"
```bash
flutter devices  # Should show android device
```

**Fix**: Start emulator of connect phone.

### "Mic not working"
- Emulator: Extended Controls → Microphone → Enable
- Better: Use real phone

### App crashes
**Windows:**
```cmd
flutter clean
flutter pub get
run_mvp.bat
```

**Linux/Mac:**
```bash
flutter clean
flutter pub get
./run_mvp.sh
```

### More help
→ See `README_MVP.md` (troubleshooting sectie)

## Volgende Stappen

**Na successful test:**

1. **Wake Word toevoegen** (als Picovoice token er is)
   - "Hee Claudine" detectie
   - Always-on listening
   - Battery optimized

2. **Backend integratie**
   - Reminders opslaan
   - WhatsApp notifications
   - Geofencing

3. **Polish**
   - Settings screen
   - History view
   - Better animations

## Status

```
✅ MVP Code Complete
✅ Android Config Done
✅ Claude API Key Set
✅ Ready to Build
✅ Windows scripts added
⏸️ Waiting: Picovoice token (wake word)

NEXT: run_mvp.bat 🚀
```

---

**Vragen? Check:**
- README_MVP.md (complete docs)
- CHECKLIST.md (test scenarios)

**Ready? Run:**

**Windows:**
```cmd
run_mvp.bat
```

**Linux/Mac:**
```bash
./run_mvp.sh
```
