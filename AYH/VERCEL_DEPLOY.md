# Deploying to Vercel

## Required: Set Root Directory

**If this is wrong, you get "404: NOT_FOUND" on the whole site.**

In your Vercel project settings (for **each** project that uses this repo, e.g. `blood-450-capf`, `blood-450-nslr`):

1. Go to **Settings** → **General** → **Root Directory**.
2. Set it to **`AYH`** (the Django project folder inside the repo).
3. Click **Save**.
4. Go to **Deployments** → open the **⋯** on the latest deployment → **Redeploy** (so the new root is used).

This ensures `vercel.json` and `AYH/wsgi.py` are found. Without it, Vercel doesn’t run your Django app and returns 404.

## Environment variables

In Vercel → **Settings** → **Environment Variables**, add:

- `DJANGO_SECRET_KEY` – a long random string (e.g. from [djecrety.ir](https://djecrety.ir/)).
- `DJANGO_DEBUG` – set to `False` for production.

### PostgreSQL (recommended for production)

Use either **Option A** (single `DATABASE_URL`) or **Option B** (individual `POSTGRES_*` vars).  
See **“How to get DATABASE_URL”** below for step-by-step for each provider.

**Option A – Single URL**

- In Vercel: add env var **`DATABASE_URL`** and paste the full URL your provider gives you (see below).

**Option B – Individual vars**

- `POSTGRES_HOST` – database host (e.g. `db.xxxx.supabase.co`)
- `POSTGRES_NAME` – database name (often `postgres`)
- `POSTGRES_USER` – database user
- `POSTGRES_PASSWORD` – your database password
- `POSTGRES_PORT` – `5432` (optional)
- `POSTGRES_SSLMODE` – `require` if the provider uses SSL (optional)

If neither is set, the app falls back to SQLite in `/tmp` (data is not persistent).

**After adding `DATABASE_URL` (Supabase etc.): run migrations once** so the database has tables. Either:
- **On Vercel:** The app runs `migrate` on cold start, so redeploy and try again; or
- **Locally:** In your project root, set `DATABASE_URL` in `.env` to the same Supabase URL, then run:
  ```bash
  python manage.py migrate
  python manage.py createsuperuser
  ```
  Then redeploy. Login will work once the tables and a user exist.

### Creating a superuser for the deployed app (Supabase)

You cannot run `createsuperuser` on Vercel (no interactive shell). Create the user **on your machine** while pointing at the **same** Supabase database the deployed app uses:

1. In your project root, ensure `.env` has the **same** `DATABASE_URL` as in Vercel (your Supabase URL), e.g.:
   ```env
   DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@db.xxxx.supabase.co:5432/postgres
   ```
2. In a terminal (from the project root, e.g. `D:\A\Blood450\AYH`):
   ```bash
   python manage.py createsuperuser
   ```
3. Enter the username, email, and password you want to use for admin login on the deployed site.
4. The user is saved in **Supabase**. Log in at `https://your-app.vercel.app/accounts/login/` (or `/admin/`) with that username and password.

---

## How to get DATABASE_URL (and other details)

### 1. Vercel Postgres (easiest if you deploy on Vercel)

1. Open [vercel.com](https://vercel.com) → your project.
2. Go to the **Storage** tab (or **Create** → **Database** → **Postgres**).
3. Create a new **Postgres** database if you don’t have one; Vercel will create a project for it.
4. After it’s created, open the database → ****.env.local** or **Connect** / **Quickstart**.
5. You’ll see something like:
   ```bash
   POSTGRES_URL="postgres://default:xxxxx@ep-xxx.region.aws.neon.tech:5432/verceldb?sslmode=require"
   ```
6. Copy that URL (with the real password in it). In your **Vercel project** (your Django app):
   - **Settings** → **Environment Variables**
   - Add **Name:** `DATABASE_URL`  
   - **Value:** paste the full URL (e.g. `postgres://default:xxxxx@ep-xxx...?sslmode=require`).
7. Redeploy. That’s all you need; no need to set `POSTGRES_HOST`, etc.

---

### 2. Supabase (free tier, good for small apps)

1. Go to [supabase.com](https://supabase.com) → sign in → **New project** (or open existing).
2. Wait for the DB to be ready, then go to **Project Settings** (gear icon) → **Database**.
3. Under **Connection string** choose **URI**.
4. Copy the URI. It looks like:
   ```text
   postgresql://postgres.[PROJECT-REF]:[YOUR-PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres
   ```
   Replace `[YOUR-PASSWORD]` with the database password you set when creating the project (or reset it in **Database** → **Database password**).
5. For Django, use **port 5432** for a direct connection (not 6543 pooler) if you see two options. Supabase often shows:
   - **Session mode** (port **5432**) – use this for Django.
   - **Transaction mode** (port **6543**) – optional for connection pooling.
   So your URL might be:
   ```text
   postgresql://postgres.[PROJECT-REF]:[YOUR-PASSWORD]@aws-0-[REGION].pooler.supabase.com:5432/postgres?sslmode=require
   ```
   Or use the **Direct connection** string from the Supabase dashboard if they show it (host like `db.xxxx.supabase.co`, port 5432).
6. In Vercel: add **`DATABASE_URL`** = this full URL (with your real password).
7. For **Option B** (individual vars), from the same Supabase **Database** page you get:
   - **Host:** e.g. `db.xxxxxxxxxxxx.supabase.co`
   - **Database name:** `postgres`
   - **User:** `postgres` (or `postgres.[PROJECT-REF]` if shown)
   - **Password:** the one you set for the project
   - **Port:** `5432`

---

### 3. Neon (free tier, serverless Postgres)

1. Go to [neon.tech](https://neon.tech) → sign in → create or open a project.
2. On the project dashboard you’ll see **Connection string** (or **Connect**).
3. Copy the connection string; it looks like:
   ```text
   postgresql://user:password@ep-xxx-xxx.region.aws.neon.tech/neondb?sslmode=require
   ```
   Use the one that includes your password (or replace the placeholder with your real password).
4. In Vercel: add **`DATABASE_URL`** = this full URL.
5. For **Option B**, from the same page you get:
   - **Host:** e.g. `ep-xxx-xxx.region.aws.neon.tech`
   - **Database:** e.g. `neondb`
   - **User** and **Password** as shown.

---

### 4. Local PostgreSQL (on your own machine)

1. Install PostgreSQL and create a database and user (e.g. with `createdb` and `createuser`, or pgAdmin).
2. Build the URL yourself:
   ```text
   postgresql://USERNAME:PASSWORD@localhost:5432/DATABASE_NAME
   ```
   Example (password `123456`, database `ayh_db`, user `ayh_user`):
   ```text
   postgresql://ayh_user:123456@localhost:5432/ayh_db
   ```
3. For **local** use, put that in your **`.env`** file in the project root:
   ```env
   DATABASE_URL=postgresql://ayh_user:123456@localhost:5432/ayh_db
   ```
4. For **Vercel**, you usually don’t use your local DB; use Vercel Postgres, Supabase, or Neon so the app can reach the DB from the internet. If your local DB is exposed (e.g. via ngrok), you could use that URL in `DATABASE_URL` on Vercel, but a cloud DB is simpler and safer.

---

### Summary

| Where you get it | What to copy | Where to set it |
|------------------|--------------|------------------|
| **Vercel Postgres** | Storage → your Postgres → `.env` / Connect → `POSTGRES_URL` or connection string | Vercel env: `DATABASE_URL` = that URL |
| **Supabase** | Project Settings → Database → Connection string (URI), replace password | Vercel env: `DATABASE_URL` = that URL |
| **Neon** | Dashboard → Connection string (with password) | Vercel env: `DATABASE_URL` = that URL |
| **Local** | You build it: `postgresql://user:password@localhost:5432/dbname` | `.env`: `DATABASE_URL` = that URL (and in Vercel only if DB is reachable from internet) |

## Troubleshooting: 404 NOT_FOUND

If you see **404: NOT_FOUND** (Vercel’s page, not Django’s):

1. **Root Directory** – In the project (e.g. `blood-450-capf`) go to **Settings** → **General** → **Root Directory**. Set it to **`AYH`** and save. Then **Redeploy** the latest deployment.
2. **Repo layout** – Your repo must contain the Django project inside a folder named `AYH` (so there is `AYH/vercel.json`, `AYH/manage.py`, `AYH/AYH/wsgi.py`). Root Directory tells Vercel to use that folder as the project root.
3. **Build logs** – In **Deployments** → click the latest deployment → check **Building** and **Runtime** logs for Python/import errors. If the build or runtime fails, the function may not be created and you get 404.

## After deploy

Your app will be at `https://<your-project>.vercel.app`.  
Log in at `/accounts/login/` or `/home/`.
