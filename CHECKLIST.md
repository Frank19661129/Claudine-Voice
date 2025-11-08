# Claudine Voice MVP - Checklist

## ✅ Klaar

### Code
- [x] `lib/main_mvp.dart` - Complete MVP in 1 bestand
  - [x] Speech-to-Text (Native Android)
  - [x] Claude API integratie (API key embedded)
  - [x] Text-to-Speech (Nederlands)
  - [x] Conversation history (last 10 exchanges)
  - [x] Visual states (idle/listening/processing/speaking)
  - [x] Animaties (pulse effect)

### Config
- [x] `pubspec_mvp.yaml` - Dependencies zonder Picovoice
- [x] `android/app/build.gradle` - Android config
- [x] `android/app/src/main/AndroidManifest.xml` - Permissions

### Scripts
- [x] `run_mvp.sh` - Quick run script
- [x] `README_MVP.md` - Complete docs
- [x] `CHECKLIST.md` - This file

### API Keys
- [x] Claude API key embedded in code
- [ ] Picovoice token - komt later (voor wake word)

## 🚀 Ready to Run

```bash
cd ~/franklab/claudine/Claudine-Voice
./run_mvp.sh
```

## 📱 Vereisten

- [x] Flutter 3.9.2+
- [ ] Android device of emulator
- [ ] Microphone access

## 🎯 Test Checklist

Na eerste run:

### Basis Functionaliteit
- [ ] App opent zonder crashes
- [ ] Microphone permission prompt verschijnt
- [ ] Blauwe idle screen zichtbaar
- [ ] Grote mic button zichtbaar

### Voice Flow
- [ ] Tap mic → paars scherm "Ik luister"
- [ ] Spreek → text verschijnt (real-time)
- [ ] Stop spreken → oranje "Even denken"
- [ ] Response → groen scherm + voice output
- [ ] Back to blue na response

### Conversatie Test
- [ ] Eerste vraag: "Hallo" → Claudine antwoordt
- [ ] Tweede vraag: "Hoe heet je?" → Context behouden
- [ ] Derde vraag: "Herinner me aan melk" → Begrijpt opdracht

### Edge Cases
- [ ] Stop button tijdens listening → stopt correct
- [ ] Stop button tijdens speaking → stopt voice
- [ ] Geen internet → error message
- [ ] Achtergrond → pauzeerd correct

## ⏸️ Later (v1.1+)

### Wake Word (na Picovoice token)
- [ ] "Hee Claudine" detectie
- [ ] Background listening
- [ ] Battery optimization
- [ ] Custom wake words

### Extra Features
- [ ] Settings screen
- [ ] Conversation history view
- [ ] Reminders naar backend
- [ ] Geofencing

## 🐛 Known Issues (Acceptabel voor MVP)

- ⚠️ Emulator mic quality is low (use real device)
- ⚠️ No background mode yet
- ⚠️ API key hardcoded (OK voor test)
- ⚠️ No error retry logic (komt later)

## 📊 Success Metrics

**MVP is successful if:**
- ✅ Builds without errors
- ✅ Runs on Android device
- ✅ Can complete full conversation cycle
- ✅ Voice quality is acceptable
- ✅ Latency < 2s total

**Current status: READY TO TEST** 🎯
