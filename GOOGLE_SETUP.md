# Google Calendar API Setup Guide

Deze guide helpt je Google Calendar API configureren voor Claudine Server.

## Stap 1: Google Cloud Project aanmaken

1. Ga naar [Google Cloud Console](https://console.cloud.google.com)
2. Klik op het project dropdown (bovenin, naast "Google Cloud")
3. Klik op "New Project"
4. Vul een naam in: bijvoorbeeld "Claudine Calendar"
5. Klik "Create"

## Stap 2: Google Calendar API inschakelen

1. Selecteer je nieuwe project (bovenin)
2. Ga naar "APIs & Services" → "Library" (linkermenu)
3. Zoek naar "Google Calendar API"
4. Klik op "Google Calendar API"
5. Klik "Enable"

## Stap 3: OAuth2 Credentials aanmaken

### 3a. Configure OAuth Consent Screen
1. Ga naar "APIs & Services" → "OAuth consent screen"
2. Kies "External" (tenzij je een Google Workspace account hebt)
3. Klik "Create"
4. Vul in:
   - **App name**: `Claudine Calendar`
   - **User support email**: je eigen email
   - **Developer contact**: je eigen email
5. Klik "Save and Continue"
6. Bij "Scopes": klik "Add or Remove Scopes"
   - Zoek en voeg toe: `Google Calendar API` → `.../auth/calendar`
   - Zoek en voeg toe: `Google Calendar API` → `.../auth/userinfo.email`
7. Klik "Save and Continue"
8. Bij "Test users": voeg je eigen Google account toe (en Nicole's account)
9. Klik "Save and Continue"

### 3b. Create OAuth2 Credentials
1. Ga naar "APIs & Services" → "Credentials"
2. Klik "Create Credentials" → "OAuth client ID"
3. Application type: kies **"TVs and Limited Input devices"**
   - Dit geeft ons Device Code Flow (zoals O365)
4. Name: `Claudine Device Flow`
5. Klik "Create"
6. Je krijgt nu een popup met Client ID en Client Secret
7. **Kopieer beide** (of download de JSON)

## Stap 4: Credentials toevoegen aan Claudine

1. Open `/home/frank/claudine/server/.env`
2. Vul in:
   ```env
   GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=GOCSPX-xxxxx
   GOOGLE_PROJECT_ID=claudine-calendar-xxxxx
   ```

## Stap 5: Server herstarten

```bash
cd /home/frank/claudine/server
docker-compose restart claudine-server
```

## Stap 6: Testen via Swagger

1. Open http://localhost:8001/docs
2. Test endpoint: `POST /api/auth/google/start`
3. Je krijgt een `user_code` en `verification_url`
4. Ga naar de URL en voer de code in
5. Log in met je Google account
6. Poll de status: `POST /api/auth/google/status` met de `device_code`
7. Als je `authenticated: true` krijgt, ben je klaar!

## Endpoints

### Google Auth
- `POST /api/auth/google/start` - Start device flow
- `POST /api/auth/google/status` - Check auth status (poll dit)
- `POST /api/auth/google/logout` - Logout

### Calendar (unified)
- `POST /api/calendar/create?provider=google` - Create event
- `GET /api/calendar/calendars?provider=google` - List calendars
- `GET /api/calendar/events?provider=google` - List events

### Auth Info (unified)
- `GET /api/auth/info` - Toont auth status voor zowel O365 als Google

## Troubleshooting

### "Invalid client" error
- Check of GOOGLE_CLIENT_ID en GOOGLE_CLIENT_SECRET correct zijn
- Check of ze geen extra spaties bevatten

### "Access blocked" tijdens login
- Check of je account is toegevoegd als "Test user" in OAuth consent screen
- Als app status "Testing" is, kunnen alleen test users inloggen
- Later kun je de app "Publish" (niet nodig voor persoonlijk gebruik)

### "Access denied" error
- Gebruiker heeft toegang geweigerd
- Probeer opnieuw met `POST /api/auth/google/start`

### "Token expired"
- Device code is verlopen (na 15 minuten)
- Start opnieuw met `POST /api/auth/google/start`

## Verschillen met O365

| Feature | O365 | Google |
|---------|------|--------|
| Auth Method | Device Code Flow (MSAL) | Device Code Flow (OAuth2) |
| API | Microsoft Graph | Google Calendar API v3 |
| Primary Calendar | `calendar` | `primary` |
| Refresh Tokens | Automatic (MSAL) | Manual refresh |
| Token Storage | Encrypted file | Encrypted file |

## Automatische Provider Detectie

Als je niet expliciet een provider specificeert, detecteert Claudine automatisch welke je hebt gebruikt:

```bash
# Expliciet Google
POST /api/calendar/create?provider=google

# Auto-detect (gebruikt eerste geauthenticeerde provider)
POST /api/calendar/create
```

## Volgende Stappen

Na setup kun je:
1. Testen via Swagger UI (http://localhost:8001/docs)
2. App updaten om provider keuze te ondersteunen
3. Nicole's account configureren op haar telefoon
