# Backend Microsoft Authentication Setup

De backend is nu geconfigureerd met Microsoft OAuth2 user authentication.

## Endpoint Details

### POST `/api/auth/user/login/microsoft`

Microsoft user login endpoint voor de Claudine Voice app.

**Base URL:** `http://100.104.213.54:8001`

**Full URL:** `http://100.104.213.54:8001/api/auth/user/login/microsoft`

## Request

**Headers:**
```json
{
  "Content-Type": "application/json"
}
```

**Body:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJub25jZ...",
  "id_token": "eyJ0eXAiOiJKV1QiLCJhbGc..." // Optional
}
```

## Response

**Success (200 OK):**
```json
{
  "success": true,
  "jwt_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "display_name": "John Doe",
  "message": "Welcome John Doe!"
}
```

**Error (401 Unauthorized):**
```json
{
  "detail": "Invalid Microsoft token"
}
```

**Error (500 Internal Server Error):**
```json
{
  "detail": "Login failed: <error details>"
}
```

## Hoe het werkt

### 1. Mobile App Flow
1. Gebruiker klikt op "Sign in with Microsoft" in de app
2. App opent Microsoft authentication webview
3. Gebruiker logt in met Microsoft account
4. Microsoft stuurt access_token en id_token terug naar de app
5. App stuurt tokens naar dit endpoint

### 2. Backend Processing
1. Backend verifieert de access_token bij Microsoft Graph API
2. Backend haalt user info op (email, naam, user ID)
3. Backend checkt of user al bestaat in database:
   - Ja: gebruik bestaande user
   - Nee: maak nieuwe user aan
4. Backend genereert JWT token voor onze systeem
5. Backend stuurt JWT token terug naar app

### 3. Subsequent Requests
De app gebruikt het ontvangen JWT token voor alle verdere API calls:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## Configuration

De backend is al geconfigureerd met de juiste credentials:

**In `/home/frank/claudine/server/.env`:**
```bash
AZURE_CLIENT_ID=b73e3922-fb5e-4d65-ad70-1f88b7c09df5
AZURE_TENANT_ID=dc636285-42a5-4f08-99b8-2e00887b3b2b
AZURE_AUTHORITY=https://login.microsoftonline.com/dc636285-42a5-4f08-99b8-2e00887b3b2b
```

## Database Schema

Users worden opgeslagen in PostgreSQL met deze velden:

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR NOT NULL,
    display_name VARCHAR NOT NULL,
    provider VARCHAR NOT NULL,  -- 'microsoft' or 'google'
    provider_user_id VARCHAR NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_provider ON users(provider, provider_user_id);
CREATE INDEX idx_users_email ON users(email);
```

## Testing

### 1. Check Server Status
```bash
curl http://100.104.213.54:8001/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "Claudine Server"
}
```

### 2. Check API Documentation
Open in browser: http://100.104.213.54:8001/docs

Look for: **POST /api/auth/user/login/microsoft**

### 3. Test with Real Token
Je hebt een echte Microsoft access_token nodig van de mobile app om te testen.

## Troubleshooting

### Error: "Invalid Microsoft token"
- Check of de access_token nog geldig is (tokens verlopen meestal na 1 uur)
- Verifieer dat de AZURE_CLIENT_ID in backend .env overeenkomt met de app registratie

### Error: "AZURE_CLIENT_ID not configured"
- Check of de .env file correct is geladen
- Restart de docker container: `docker restart claudine-server`

### Error: "Failed to get user info from Microsoft"
- Check of de token de juiste scopes heeft (openid, profile, email)
- Verifieer dat Microsoft Graph API bereikbaar is
- Check server logs: `docker logs claudine-server --tail 100`

### Error: "Database connection failed"
- Check of claudine-server-db container draait: `docker ps | grep db`
- Check database credentials in .env

## Related Files

### Backend
- **Endpoint:** `/home/frank/claudine/server/app/routers/auth.py` (regel 519-578)
- **Service:** `/home/frank/claudine/server/app/services/microsoft_login.py`
- **Config:** `/home/frank/claudine/server/.env`

### Mobile App
- **Auth Service:** `/mnt/d/dev/claudine/claudine-voice/lib/services/auth_service.dart`
- **Login Screen:** `/mnt/d/dev/claudine/claudine-voice/lib/screens/login_screen.dart`
- **Config:** `/mnt/d/dev/claudine/claudine-voice/.env`

## API Flow Diagram

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│             │         │              │         │             │
│  Mobile App │         │   Backend    │         │  Microsoft  │
│             │         │              │         │    Graph    │
└──────┬──────┘         └──────┬───────┘         └──────┬──────┘
       │                       │                        │
       │ 1. Login with MS      │                        │
       ├──────────────────────►│                        │
       │                       │                        │
       │                       │ 2. Verify token        │
       │                       ├───────────────────────►│
       │                       │                        │
       │                       │ 3. User info           │
       │                       │◄───────────────────────┤
       │                       │                        │
       │                       │ 4. Check/Create user   │
       │                       │    in database         │
       │                       │                        │
       │ 5. JWT token          │                        │
       │◄──────────────────────┤                        │
       │                       │                        │
       │ 6. API calls with JWT │                        │
       ├──────────────────────►│                        │
       │                       │                        │
```

## Next Steps

1. ✅ Backend endpoint is live
2. ✅ Database is configured
3. ✅ Azure credentials zijn ingesteld
4. 🔄 Test de volledige flow met de mobile app
5. 🔄 Monitor logs tijdens eerste logins

## Support

Als je problemen hebt:
1. Check server logs: `docker logs claudine-server --tail 100 -f`
2. Check API docs: http://100.104.213.54:8001/docs
3. Test health endpoint: `curl http://100.104.213.54:8001/health`
