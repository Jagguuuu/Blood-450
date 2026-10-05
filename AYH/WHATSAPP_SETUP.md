# WhatsApp Integration — Blood450

## Correct architecture (development)

| Role | What it is |
|------|------------|
| **Business** | Meta **test** WhatsApp number (`WHATSAPP_PHONE_NUMBER_ID` / `WHATSAPP_BASE_PHONE_DISPLAY`) |
| **Donor** | Normal personal WhatsApp on their phone — **not** registered as a WABA number |
| **Direction** | Donor messages business → Meta webhook → Django → auto-reply via Cloud API |

```text
Donor (personal WhatsApp)
    → Meta test business number (+1 555 656-5019)
    → POST /api/whatsapp/webhook/
    → receive_whatsapp_message() / handle_inbound_text()
    → _maybe_auto_reply() → Meta Cloud API send (session)
    → Donor receives reply on personal WhatsApp
```

## Meta development setup (required)

1. [developers.facebook.com](https://developers.facebook.com) → your app → **WhatsApp** → **API Setup**.
2. Copy **Phone number ID** → `WHATSAPP_PHONE_NUMBER_ID`.
3. Copy **Access token** → `WHATSAPP_ACCESS_TOKEN`.
4. Under **“To” / test recipients**, add the donor’s **full** mobile number (country code, digits only e.g. `919876543210`).  
   Without this, outbound replies fail with error **#131030** (recipient not in allowed list).
5. Donor opens WhatsApp on their phone and sends a message **to the test business number** (not the other way around first).
6. Webhook callback: `https://YOUR_PUBLIC_HOST/api/whatsapp/webhook/`
7. Verify token = `WHATSAPP_VERIFY_TOKEN`
8. Subscribe to: **`messages`**, **`message_status`**
9. Use a tunnel that Meta can reach (cloudflared recommended; ngrok free may block bots).

## Environment variables (`.env`)

```env
WHATSAPP_PROVIDER=meta
WHATSAPP_ACCESS_TOKEN=
WHATSAPP_PHONE_NUMBER_ID=
WHATSAPP_BUSINESS_ACCOUNT_ID=
WHATSAPP_VERIFY_TOKEN=blood450_meta_verify_2026
WHATSAPP_APP_SECRET=
WHATSAPP_API_VERSION=v20.0
WHATSAPP_BASE_PHONE_DISPLAY=+1 (555) 656-5019
WHATSAPP_DEFAULT_COUNTRY_CODE=91
WHATSAPP_VALIDATE_PHONE_NUMBER_ID=true
WHATSAPP_WEBHOOK_SKIP_SIGNATURE=true
WHATSAPP_AUTO_REPLY_ENABLED=true
# Donor must message business first in dev — do not spam welcome/alerts until production:
WHATSAPP_PROACTIVE_OUTBOUND=false
WHATSAPP_SEND_WELCOME_ON_REGISTER=false
```

Use `WHATSAPP_PROVIDER=console` to test inbox without Meta (no real sends).

## Verify locally

```bash
cd AYH
python manage.py whatsapp_check_flow
python manage.py whatsapp_check_flow --simulate 919876543210 "Hello"
python manage.py whatsapp_simulate_inbound 919876543210 "Hello"
```

Run server (webhook + optional WebSocket chat):

```bash
daphne -b 0.0.0.0 -p 8000 AYH.asgi:application
```

Watch console for:

- `[WEBHOOK] POST` — Meta reached Django
- `[WEBHOOK] IN from=...` — donor phone + text
- `[WhatsApp IN]` / `[WhatsApp AUTO-REPLY]` — processing + reply

## API endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET/POST | `/api/whatsapp/webhook/` | Meta verification + inbound |
| GET | `/api/whatsapp/unread/` | Unread badge count |
| GET | `/api/whatsapp/conversations/` | List threads |
| GET | `/api/whatsapp/conversations/<id>/messages/` | Paginated messages |
| POST | `/api/whatsapp/conversations/<id>/send/` | Admin manual reply |
| POST | `/api/whatsapp/blood-alert/` | Blood alert (needs `WHATSAPP_PROACTIVE_OUTBOUND=true`) |

## Admin / donor UI

- Admin dashboard: WhatsApp chat widget (live when Daphne + Redis/channel layer running).
- Donor app: Support chat (REST; WebSocket optional).

## Production notes

- Set `WHATSAPP_PROACTIVE_OUTBOUND=true` when approved for production messaging.
- Set `WHATSAPP_WEBHOOK_SKIP_SIGNATURE=false` and configure `WHATSAPP_APP_SECRET`.
- Use approved **template** messages for first contact outside the 24-hour window.
