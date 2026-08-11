# Deploy Django AYH to Vercel

This guide covers deploying the AYH Django app to Vercel (production) and how to run things like migrations and creating dummy donors.

---

## 1. Prerequisites

- **GitHub repo** with your code (e.g. `blood-450-main` with an `AYH` folder inside).
- **PostgreSQL database** for production (Vercel serverless does not use SQLite). Use one of:
  - [Supabase](https://supabase.com) (free tier) → **Project Settings → Database** → use the **Connection pooling** (Transaction) URI for serverless, not the direct Session URI on port 5432 (to avoid “Tenant or user not found”).
  - [Neon](https://neon.tech) (free tier) → Connection string
  - Any other PostgreSQL host

The connection string looks like:
`postgres://USER:PASSWORD@HOST:PORT/DATABASE?sslmode=require`

---

## 2. Vercel project setup

1. Go to [vercel.com](https://vercel.com) and sign in (GitHub).
2. **Add New** → **Project** → Import your Git repository.
3. **Root Directory**: set to **`AYH`** (so Vercel uses the folder that contains `manage.py`, `vercel.json`, and `requirements.txt`).
4. **Framework Preset**: leave as “Other” (no framework).
5. **Build and Output Settings** (optional; override if needed):
   - **Build Command:** `python manage.py collectstatic --noinput`
   - **Output Directory:** leave empty (Python serverless does not use it).
   - **Install Command:** `pip install -r requirements.txt` (often auto-detected).

---

## 3. Environment variables

In the Vercel project: **Settings → Environment Variables**. Add:

| Name | Value | Notes |
|------|--------|--------|
| `DATABASE_URL` | Your PostgreSQL URI (Supabase: use **Connection pooling** URI from Project Settings → Database). | **Required** on Vercel. Wrong or old URI causes “Tenant or user not found” and 500s. |
| `DJANGO_SECRET_KEY` | A long random string | Use a new secret for production. |
| `DJANGO_ENV` | `production` | So `IS_PRODUCTION` is True. |

Optional:

- `DJANGO_DEBUG` = `0` or leave unset (defaults to False in production).
- `APP_BASE_URL` = `https://your-app.vercel.app` (e.g. `https://blood-450-gqkc.vercel.app`). If unset, the app uses `VERCEL_URL` automatically on Vercel.
- **Google Sign-In:** `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`. You can leave `GOOGLE_REDIRECT_URI` unset; it is built from `APP_BASE_URL` (or `https://$VERCEL_URL` on Vercel).
- Any other keys your app reads (e.g. Twilio, etc.).

**Important for Google Sign-In on Vercel:** In [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → your OAuth 2.0 Client ID → add:

- **Authorised JavaScript origins:** `https://blood-450-gqkc.vercel.app` (use your actual Vercel URL).
- **Authorised redirect URIs:** `https://blood-450-gqkc.vercel.app/register/google/callback/` (trailing slash must match).

If these are missing or the URL is wrong, Google login will fail (e.g. redirect_uri_mismatch or 500).

Then **Save** and **Redeploy** so the new env vars are used.

---

## 4. Deploy

- Push to your connected branch (e.g. `main`); Vercel will build and deploy.
- Or trigger a redeploy from the Vercel dashboard.

Your app will be at: `https://<your-project>.vercel.app`.

---

## 5. Run migrations (first time and after model changes)

Vercel runs your app as serverless; it does not run `manage.py` for you. Run migrations **once per deployment** (or when you change models) using one of these:

### Option A: Local with production DB (recommended)

Use the same `DATABASE_URL` as in Vercel and run from your machine (from the **AYH** folder):

```bash
cd AYH
set DATABASE_URL=postgres://USER:PASSWORD@HOST:PORT/DATABASE?sslmode=require
python manage.py migrate
```

(On macOS/Linux use `export DATABASE_URL=...`.)

### Option B: Vercel CLI one-off

If you use Vercel CLI and have a way to run a one-off command (e.g. “Run command” in dashboard or a script that invokes `vercel env pull` and then `migrate`), you can run:

```bash
vercel env pull .env.local
python manage.py migrate
```

from the **AYH** directory after pulling env.

---

## 6. Create dummy donors in production

`create_dummy_donors.py` is meant to be run **locally** with the **production** `DATABASE_URL`:

1. In Vercel: **Settings → Environment Variables** → copy `DATABASE_URL` (or use **Vercel CLI**: `vercel env pull .env.local`).
2. From the **AYH** folder:

```bash
cd AYH
set DATABASE_URL=postgres://...   # same as in Vercel
python create_dummy_donors.py
```

Then enter the number of donors (1–500) when prompted. They will be created in the same PostgreSQL database that the deployed app uses.

Do **not** run this script on Vercel’s serverless runtime; run it on your machine (or a one-off job elsewhere) with `DATABASE_URL` set.

---

## 7. After deployment checklist

- [ ] **Root Directory** is `AYH`.
- [ ] **DATABASE_URL** is set and points to PostgreSQL.
- [ ] **DJANGO_SECRET_KEY** and **DJANGO_ENV=production** are set.
- [ ] Migrations have been run at least once against the production DB.
- [ ] If you use a custom domain, add it in Vercel and add that origin to `CSRF_TRUSTED_ORIGINS` and `ALLOWED_HOSTS` in `AYH/settings.py` (or via env if you add support for it).

---

## 8. Troubleshooting

- **“DATABASE_URL is missing”**  
  Add `DATABASE_URL` in Vercel Environment Variables and redeploy.

- **500 on every request + “FATAL: Tenant or user not found” (Supabase)**  
  Your app cannot connect to the database. This causes 500 on `/admin/login/`, `/register/google/`, and any page that touches the DB.

  1. **Get a fresh connection string from Supabase**
     - Open [Supabase Dashboard](https://supabase.com/dashboard) → your project → **Project Settings** (gear) → **Database**.
     - Under **Connection string**, choose **URI**.
     - For **Vercel (serverless)**, use the **Connection pooling** string (Transaction mode, port **6543**, or Session mode if your region uses it). Do **not** use the direct “Session” connection on port 5432 for serverless unless Supabase explicitly documents it for your region.
     - Copy the URI. It should look like:  
       `postgres://postgres.[PROJECT-REF]:[YOUR-PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres`  
       or similar. Replace `[YOUR-PASSWORD]` with your database password (not the pooler password if different).
  2. **Ensure the username includes the project reference**  
     Some Supabase pooler URLs require the project ref in the user, e.g. `postgres.abcdefghijklmnop` instead of just `postgres`. Use the exact string from the Supabase “Connection pooling” section.
  3. **Update Vercel**
     - Vercel → Project → **Settings** → **Environment Variables**.
     - Set `DATABASE_URL` to the new value (Production, and optionally Preview).
     - **Redeploy** (Deployments → … → Redeploy) so the new env is used.

  If the project was paused or recreated, create a new project and use its new connection string.

- **Static files 404**  
  Ensure Build Command runs `python manage.py collectstatic --noinput` and that WhiteNoise is in `MIDDLEWARE` (already in your settings).

- **CSRF / cookie errors / admin login not redirecting**  
  The app adds your Vercel URL to `CSRF_TRUSTED_ORIGINS` automatically when `APP_BASE_URL` is set or when `VERCEL_URL` is present. Ensure `APP_BASE_URL` (or Vercel’s automatic `VERCEL_URL`) matches your live URL so cookies and redirects work.

- **Google Sign-In 500 or “redirect_uri_mismatch”**  
  1) Set `GOOGLE_OAUTH_CLIENT_ID` and `GOOGLE_OAUTH_CLIENT_SECRET` in Vercel.  
  2) In Google Cloud Console, add **Authorised JavaScript origins:** `https://your-app.vercel.app` and **Authorised redirect URIs:** `https://your-app.vercel.app/register/google/callback/` (exact URL, including trailing slash).

- **Migrations not applied**  
  Run `python manage.py migrate` locally with `DATABASE_URL` set to your production DB.

- **“No directory at: …/staticfiles/” in logs**  
  On Vercel, the build may not persist `staticfiles` into the serverless bundle. If admin/static assets still load (e.g. admin CSS), you can ignore this. If you get 404s on static files, ensure the Build Command runs `python manage.py collectstatic --noinput` and that the output directory is included in your deployment (see [Vercel docs](https://vercel.com/docs/functions/serverless-functions/runtimes#bundled-files) for Python).
