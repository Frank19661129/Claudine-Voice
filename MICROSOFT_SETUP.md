# Microsoft Azure AD Authentication Setup

Dit document beschrijft hoe je Microsoft authentication configureert voor Claudine Voice.

## Vereiste Informatie

Voor de Android app heb je de volgende gegevens nodig:

- **Package Name:** `com.franklab.claudine_voice`
- **Signature Hash (Base64-encoded SHA1):** `pfcoW2cCXjT5NJV6ZUXd1F1UAfA=`
- **Redirect URI:** `msauth://com.franklab.claudine_voice/pfcoW2cCXjT5NJV6ZUXd1F1UAfA`

> **Let op:** Azure Portal verwacht de signature hash in **Base64** formaat, niet Hex!

## Azure Portal Configuratie

### Stap 1: App Registratie Aanmaken

1. Ga naar [Azure Portal](https://portal.azure.com)
2. Navigeer naar **Azure Active Directory** (of **Microsoft Entra ID**)
3. Klik op **App registrations** in het linkermenu
4. Klik op **+ New registration**

### Stap 2: App Configureren

1. **Name:** Vul in: `Claudine Voice`
2. **Supported account types:** Kies een van de volgende opties:
   - **Accounts in this organizational directory only** - Voor één organisatie
   - **Accounts in any organizational directory** - Voor meerdere organisaties
   - **Accounts in any organizational directory and personal Microsoft accounts** - Voor organisaties én persoonlijke accounts
3. **Redirect URI:** Laat dit nu nog leeg (we voegen dit later toe)
4. Klik op **Register**

### Stap 3: Credentials Kopiëren

Na registratie zie je het **Overview** scherm:

1. Kopieer de **Application (client) ID** - dit is je `MS_OAUTH_CLIENT_ID`
2. Kopieer de **Directory (tenant) ID** - dit is je `MS_OAUTH_TENANT_ID`

### Stap 4: Android Platform Toevoegen

1. Klik in het linkermenu op **Authentication**
2. Klik op **+ Add a platform**
3. Selecteer **Android**
4. Vul de volgende gegevens in:
   - **Package name:** `com.franklab.claudine_voice`
   - **Signature hash:** `pfcoW2cCXjT5NJV6ZUXd1F1UAfA=`
5. Klik op **Configure**

> **Let op:** Azure Portal verwacht de signature hash in **Base64** formaat!
> - Als je een nieuwe platform toevoegt: gebruik Base64 format
> - Het hex formaat met colons werkt mogelijk in sommige oudere interfaces

### Stap 5: API Permissions (Optioneel)

Als je extra permissions nodig hebt:

1. Klik in het linkermenu op **API permissions**
2. De volgende permissions zijn al standaard toegevoegd:
   - `User.Read` (Microsoft Graph)
3. Voor email en profile info, voeg toe:
   - `email`
   - `profile`
   - `openid`

## .env Configuratie

Update je `.env` file met de gekopieerde credentials:

```bash
# Microsoft Azure AD OAuth (for user authentication)
MS_OAUTH_CLIENT_ID=<paste_your_client_id_here>
MS_OAUTH_TENANT_ID=<paste_your_tenant_id_here>
MS_OAUTH_REDIRECT_URI=msauth://com.franklab.claudine_voice/pfcoW2cCXjT5NJV6ZUXd1F1UAfA
```

## Backend Configuratie

Je backend moet een endpoint aanmaken om Microsoft tokens te verifiëren:

### Endpoint: `POST /api/auth/user/login/microsoft`

**Request Body:**
```json
{
  "id_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "access_token": "eyJ0eXAiOiJKV1QiLCJub25jZ..."
}
```

**Response:**
```json
{
  "jwt_token": "your_jwt_token",
  "user_id": "user_id",
  "email": "user@example.com",
  "display_name": "User Name"
}
```

### Token Verificatie

De backend moet:

1. Het ID token verifiëren met Microsoft's public keys
2. De tenant ID en client ID checken
3. User info extracten uit het token
4. Een JWT token genereren voor je eigen systeem
5. User opslaan/updaten in je database

### Voorbeeld Verificatie (Python)

```python
from msal import ConfidentialClientApplication
import jwt

def verify_microsoft_token(id_token, client_id, tenant_id):
    # Verify the token signature and claims
    # This is a simplified example
    decoded = jwt.decode(
        id_token,
        options={"verify_signature": False},  # In productie: verify_signature=True
        audience=client_id
    )

    # Check tenant
    if decoded.get('tid') != tenant_id:
        raise ValueError("Invalid tenant")

    return {
        'email': decoded.get('preferred_username') or decoded.get('email'),
        'name': decoded.get('name'),
        'sub': decoded.get('sub')  # Unique user ID
    }
```

## Testen

1. Start de backend server
2. Update de `.env` met je credentials
3. Run `flutter pub get`
4. Build en run de app
5. Klik op "Sign in with Microsoft"
6. Log in met een Microsoft account
7. Check de logs voor succesvolle authenticatie

## Troubleshooting

### "AADSTS50011: The redirect URI specified in the request does not match"

- Check of de redirect URI exact overeenkomt in Azure Portal
- Check of de signature hash correct is

### "Failed to get Microsoft ID token"

- Check of de MS_OAUTH credentials correct zijn in `.env`
- Check of je internetverbinding werkt
- Check of de tenant ID correct is

### Backend errors

- Check of het `/api/auth/user/login/microsoft` endpoint bestaat
- Check of de backend de tokens correct verifieert
- Check de backend logs voor meer details

## Voor Release Builds

Voor release builds moet je een nieuwe signature hash genereren:

```powershell
# Run dit script met je release keystore
.\Get-MSAuthHash.ps1
```

Of handmatig:

```bash
keytool -list -v -keystore your-release-keystore.jks -alias your-key-alias
```

Voeg dan de nieuwe signature hash toe in Azure Portal (je kunt meerdere hashes hebben voor debug en release builds).

## Nuttige Links

- [Microsoft Identity Platform Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/)
- [MSAL for Android](https://docs.microsoft.com/en-us/azure/active-directory/develop/tutorial-v2-android)
- [Azure Portal](https://portal.azure.com)
