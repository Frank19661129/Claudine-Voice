# Claudine Voice - MVP (Android)

**Tap-to-talk versie** zonder wake word (komt later als Picovoice token er is).

## ✨ Features MVP

- ✅ Tap microfoon knop → spreek
- ✅ Speech-to-Text (Native Android)
- ✅ Claude AI conversatie
- ✅ Text-to-Speech (Nederlands)
- ✅ Visual feedback (kleuren + animatie)
- ⏸️ Wake word ("Hee Claudine") - komt later

## 🚀 Quick Start

### 1. Vereisten

```bash
flutter --version  # 3.9.2+
```

Android device of emulator met microfoon.

### 2. Run

```bash
cd ~/franklab/claudine/Claudine-Voice
./run_mvp.sh
```

Dat is alles! Script doet:
- Installeer dependencies
- Check Android device
- Build & run app
- API key zit al in code

### 3. Gebruik

1. **App opent** → Vraagt om microphone permission → Allow
2. **Blauw scherm** → "Tik op de microfoon"
3. **Tap grote mic button** → Paars scherm "Ik luister..."
4. **Spreek** je vraag (bijv: "Hoe laat is het?")
5. **Oranje** → "Even denken..."
6. **Groen** → Claudine antwoordt (voice)
7. **Terug naar blauw** → Klaar voor volgende vraag

## 📱 Android Setup (Eenmalig)

### USB Debugging Enablen

```
Android Phone:
1. Settings → About Phone
2. Tap "Build Number" 7x (becomes developer)
3. Settings → Developer Options → USB Debugging [ON]
4. Connect USB → Allow computer
```

### Emulator Starten

```bash
# List available emulators
flutter emulators

# Start one
flutter emulators --launch Pixel_7_API_34

# Or use Android Studio: Tools → Device Manager → Play
```

## 🎯 Test Scenarios

### Basis Test

```
You: "Hallo"
Claudine: "Hallo! Hoe kan ik je helpen?"

You: "Herinner me aan melk kopen"
Claudine: "Natuurlijk! Wanneer wil je dat ik je herinner?"

You: "Rond 18 uur"
Claudine: "Oké, ik zet een reminder voor vandaag 18:00."
```

### Conversatie Context Test

```
You: "Wat is de hoofdstad van Frankrijk?"
Claudine: "Parijs is de hoofdstad van Frankrijk."

You: "Hoeveel inwoners?"
Claudine: "Parijs heeft ongeveer 2,2 miljoen inwoners."
```

Claudine onthoudt laatste 10 exchanges!

## 🎨 UI States

| Kleur | Status | Actie |
|-------|--------|-------|
| **Blauw** | Idle | Tap mic button |
| **Paars** | Listening | Aan het luisteren (pulse animatie) |
| **Oranje** | Processing | Claude denkt na |
| **Groen** | Speaking | Claudine spreekt |

## 🔧 Troubleshooting

### "No Android device found"

```bash
# Check devices
flutter devices

# Should show: "Android SDK built for x86_64 • emulator-5554 • android"
```

**Fix:**
- Start emulator: `flutter emulators --launch <name>`
- Or connect phone via USB
- Enable USB debugging on phone

### "Microphone permission denied"

**Fix:**
- Uninstall app
- Reinstall: `flutter run --target=lib/main_mvp.dart`
- When prompted: Allow microphone

### "Speech recognition not working"

**Check:**
```bash
# Mic working in emulator?
# Emulator → Extended Controls → Microphone → Enable

# Or test on real device (better quality)
```

### "Claude API error"

**API Key check:**
- Key in `lib/main_mvp.dart` line 25
- Should start with: `sk-ant-api03-`
- Test in browser: https://console.anthropic.com/

### "App crashes on start"

```bash
# Clean build
flutter clean
flutter pub get
flutter run --target=lib/main_mvp.dart -d android
```

## 📊 Performance

**Android Phone (2024):**
- Speech → Text: ~200ms
- Claude response: ~800ms (depends on network)
- Text → Speech: ~100ms
- **Total latency: ~1.1s**

**Emulator:**
- Can be slower (~2-3s total)
- Mic quality lower
- Use real device for best experience

## 🔋 Battery Usage

**MVP (tap-to-talk only):**
- Idle: ~0.5% per uur
- Active conversation: ~5% per uur

**Later (met wake word):**
- Wake word active: ~2% per uur
- Hele dag aan: ~35-40% battery

## 🐛 Known Issues MVP

1. **No wake word** - Moet manual tap (komt later)
2. **Emulator mic** - Kan wonky zijn, use real device
3. **Background** - Stopt als app naar achtergrond gaat
4. **Internet required** - Claude API = online only

## 📂 Code Structure

```
lib/
└── main_mvp.dart          # Complete MVP in 1 file
    ├── SpeechToText       # Native Android STT
    ├── FlutterTts         # Native TTS
    ├── Claude API         # HTTP calls
    └── UI                 # Single screen

Simplified vs full version:
- No wake word service
- No separate services/
- API key hardcoded
- Single file = easy debug
```

## 🚀 Volgende Stappen

### v1.1 - Wake Word
```
Wanneer Picovoice token er is:
- [ ] Add wake word detection
- [ ] "Hee Claudine" trigger
- [ ] Background listening
```

### v1.2 - Features
```
- [ ] Settings screen
- [ ] Conversation history
- [ ] Reminders → backend
- [ ] Geofencing
```

### v1.3 - Polish
```
- [ ] Better animations
- [ ] Sound effects
- [ ] Haptic feedback
- [ ] Battery optimization UI
```

## 💡 Tips

**Beste resultaten:**
- Gebruik real Android device (geen emulator)
- Rustige omgeving (minder background noise)
- Spreek duidelijk (niet te snel)
- Wacht op paars scherm before speaking

**Sneller testen:**
- Hot reload werkt: `r` in terminal
- Hot restart: `R` in terminal
- Stop: `q` in terminal

**Debug:**
- Logs: `flutter logs`
- Filter: `flutter logs | grep Claudine`

## 📞 Support

Issues? Check:
1. README_MVP.md (this file)
2. Troubleshooting sectie (boven)
3. Flutter doctor: `flutter doctor -v`

## 🎯 Success Criteria MVP

- [x] Tap button → listen
- [x] Speech → text works
- [x] Claude API responds
- [x] Text → speech works
- [x] Visual feedback clear
- [x] Can have conversation (context)
- [x] Runs on Android

**MVP is complete! 🎉**

Volgende: Add wake word when Picovoice token ready.
