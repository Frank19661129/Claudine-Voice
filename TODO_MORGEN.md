# Fix: Afspraak in BEIDE agenda's maken

## Probleem
Gebruiker zegt: "Maak een afspraak morgen om 10 uur kerk in beide agenda's"
→ Alleen O365 event wordt aangemaakt
→ Monitor toont maar 1 request

## Oorzaak
Claude genereert maar 1 CALENDAR tag:
```
[CALENDAR:{"title":"Kerk","date":"2025-11-09","time":"10:00","provider":"o365"}]
```

Maar we hebben 2 events nodig (o365 + google)!

## Oplossing

### 1. Claude prompt updaten (main.dart regel ~438)

**Huidige prompt:**
```dart
[CALENDAR:{"title":"...","provider":"o365 of google"}]
```

**Nieuwe prompt:**
```dart
// Als gebruiker zegt "beide agenda's" of "allebei":
[CALENDAR:{"title":"...","provider":"o365"}]
[CALENDAR:{"title":"...","provider":"google"}]

// Dus TWEE tags achter elkaar!
```

**Toevoegen aan systemprompt (na regel 444):**
```dart
- Als gebruiker zegt "beide agenda's" of "allebei" → maak TWEE CALENDAR tags (één voor o365, één voor google)

Voorbeeld 3 (beide agenda's):
Gebruiker: "Maak een afspraak voor morgen om 10 uur kerk in beide agenda's"
Jij: "Ik maak de afspraak in beide agenda's. [CALENDAR:{"title":"Kerk","date":"2025-11-06","time":"10:00","location":"Kerk","provider":"o365"}][CALENDAR:{"title":"Kerk","date":"2025-11-06","time":"10:00","location":"Kerk","provider":"google"}]"
```

### 2. Parsing updaten om MEERDERE tags te vinden (main.dart regel ~523)

**Huidige code:**
```dart
if (answer.contains('[CALENDAR:')) {
  final match = RegExp(r'\[CALENDAR:(.*?)\]').firstMatch(answer);  // ← EERSTE match
  if (match != null) {
    _createCalendarEvent(calendarJson!);  // ← 1 event
  }
}
```

**Nieuwe code:**
```dart
if (answer.contains('[CALENDAR:')) {
  debugPrint('✅ CALENDAR tag(s) found in answer!');

  // Vind ALLE calendar tags (niet alleen eerste)
  final matches = RegExp(r'\[CALENDAR:(.*?)\]').allMatches(answer);

  if (matches.isNotEmpty) {
    // Verwijder alle CALENDAR tags uit display
    displayAnswer = answer;
    for (final match in matches) {
      displayAnswer = displayAnswer.replaceAll(match.group(0)!, '').trim();
    }

    debugPrint('📅 Found ${matches.length} calendar event(s)');

    // Maak elk event aan
    for (final match in matches) {
      final calendarJson = match.group(1);
      debugPrint('📅 Processing calendar event: $calendarJson');
      _createCalendarEvent(calendarJson!);
    }
  }
}
```

### 3. Test scenario's

**Test 1: Beide agenda's expliciet**
```
"Maak een afspraak morgen om 10 uur kerk in beide agenda's"
→ Verwacht: 2 events (O365 + Google)
→ Monitor: 2 requests
```

**Test 2: Beide agenda's met synoniem**
```
"Maak een afspraak morgen om 11 uur meeting in allebei mijn agenda's"
→ Verwacht: 2 events
```

**Test 3: Nog steeds 1 agenda werkt**
```
"Maak een afspraak morgen om 14 uur dokter in mijn Google agenda"
→ Verwacht: 1 event (alleen Google)
```

## Implementatie stappen

1. Open `lib/main.dart`
2. **Regel ~450**: Voeg voorbeeld toe aan systemprompt (beide agenda's scenario)
3. **Regel ~523**: Vervang `firstMatch` door `allMatches` + loop
4. Test met voice command: "afspraak morgen 10 uur test in beide agenda's"
5. Check monitor: moet 2 requests tonen

## Versie
Verhoog naar **1.0.0+12**

## Verwachte resultaat
```
Monitor toont:
1. Calendar Event Create (o365) - 200 Success
2. Calendar Event Create (google) - 200 Success

Beide agenda's hebben nu hetzelfde event!
```

---
Geschatte tijd: 15 minuten
Klaar voor implementatie morgenochtend! ☕
