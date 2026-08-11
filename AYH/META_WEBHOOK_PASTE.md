# Meta Webhook — paste these values (Blood450)

## Security

You shared tokens in chat. After setup works, **regenerate** the permanent token in Meta:
**App → WhatsApp → API Setup → Access token → Regenerate**

---

## Step 1 — Start Django (must be running before Verify)

```powershell
cd AYH
daphne -b 0.0.0.0 -p 8000 AYH.asgi:application
```

Or: `python manage.py runserver 0.0.0.0:8000` (webhook verify works; live chat needs daphne).

---

## Step 2 — Public HTTPS URL (Meta cannot use localhost)

Install [ngrok](https://ngrok.com), then:

```powershell
ngrok http 8000
```

Copy the **https** URL, e.g. `https://a1b2c3d4.ngrok-free.app`

---

## Step 3 — Paste in Meta (your screenshot: Configure Webhooks)

| Field in Meta | Paste this |
|---------------|------------|
| **Callback URL** | `https://YOUR-NGROK-ID.ngrok-free.app/api/whatsapp/webhook/` |
| **Verify token** | `blood450_meta_verify_2026` |

Click **Verify and save**.

- If it fails: Django not running, wrong token, or ngrok URL typo (must end with `/api/whatsapp/webhook/`).
- Test in browser (should NOT work as normal page):  
  `https://YOUR-NGROK-ID.ngrok-free.app/api/whatsapp/webhook/?hub.mode=subscribe&hub.verify_token=blood450_meta_verify_2026&hub.challenge=12345`  
  Should return plain text: `12345`

---

## Step 4 — Subscribe to fields

After verify, click **Manage** / **Webhook fields** and subscribe:

- `messages`
- `message_status` (or `statuses`)

---

## Step 5 — Test with Meta test number

Your `.env` is set for:

- **Phone number ID:** `1125392553991209`
- **Test line:** `+1 (555) 656-5019`
- **WABA ID:** `958010120358817`

In Meta → **API Setup**:

1. Under **To**, add **your personal mobile** (with country code, e.g. `91xxxxxxxxxx`) as a test recipient.
2. Send a test message from the dashboard to your phone, or send a WhatsApp message **to** the test business number from your phone.
3. Open Blood450 admin → green WhatsApp button → message should appear.

---

## Values already in `.env`

```
WHATSAPP_PROVIDER=meta
WHATSAPP_PHONE_NUMBER_ID=1125392553991209
WHATSAPP_BUSINESS_ACCOUNT_ID=958010120358817
WHATSAPP_VERIFY_TOKEN=blood450_meta_verify_2026
```

Permanent access token is stored in `.env` (do not commit `.env` to git).

---

## Production (Vercel / real domain)

Replace ngrok URL with:

```text
https://YOUR-PRODUCTION-DOMAIN/api/whatsapp/webhook/
```

Same verify token: `blood450_meta_verify_2026`

Add **App Secret** to `.env` as `WHATSAPP_APP_SECRET` from  
https://developers.facebook.com/apps/1403885118092650/settings/basic/
