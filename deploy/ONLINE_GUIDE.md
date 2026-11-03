# Put the OilMitra operator console online (Neon + Render)

```
 Operators / browsers ──https──▶ Render (free web service, Singapore)
                                   └─ FastAPI + operator app at /admin/
                                        │
                                        ▼
                                   Neon (free PostgreSQL)
                                   └─ SAME data as the supplier app
```

Deploying this repository separately is **optional**: the main `oilmitra` repository already serves `/admin/`. Use this repository when you want operators to have their own URL.

## Important: share one database

Both services must use the **same** Neon connection string. Otherwise suppliers and operators see different data.

- `DATABASE_URL` → the same value in both Render services.
- `ADMIN_USERNAMES` → the same usernames in both.
- Never point this service at a second database unless you deliberately want separate data.

---

## Step 1 — Use the existing Neon database

If the main OilMitra service is already online, reuse its `DATABASE_URL`.

If not, create it first:

1. Go to <https://neon.tech> → **Sign up**.
2. Create a project: name `oilmitra`, region **AWS Asia Pacific (Singapore)**.
3. Click **Connect** and copy the connection string.
4. Keep it secret.

## Step 2 — Push this folder to GitHub

On <https://github.com> → **New repository** → name `oilmitra-operator` → **Private** (or Public) → do not add a README → **Create repository**.

In **cmd** (replace `YOUR-NAME`):

```bat
cd /d F:\OilMitra\live\oilmitra-operator
git init -b main
git add .
git commit -m "OilMitra operator console"
git remote add origin https://github.com/YOUR-NAME/oilmitra-operator.git
git push -u origin main
```

Later updates:

```bat
cd /d F:\OilMitra
deploy\prepare_online.bat
deploy\make_live.bat
cd live\oilmitra-operator
git add .
git commit -m "update"
git push
```

## Step 3 — Run it on Render

1. Go to <https://render.com> → **New → Blueprint**.
2. Choose the `oilmitra-operator` repository.
3. Paste the **same** Neon connection string for `DATABASE_URL`.
4. Set `ADMIN_USERNAMES` to your operator username(s).
5. Click **Apply** and wait for the first build.
6. When it says **Live**, note the address, e.g. `https://oilmitra-operator.onrender.com`.

## Step 4 — Test

- Health: `https://YOUR-OPERATOR-SERVICE.onrender.com/`
- Operator console: `https://YOUR-OPERATOR-SERVICE.onrender.com/admin/`
- API docs: `https://YOUR-OPERATOR-SERVICE.onrender.com/docs`

Create the operator account:

1. Open `/admin/` and choose **Create operator**.
2. Use a username listed in `ADMIN_USERNAMES`.
3. Pick a strong password and sign in.

Verify that loads created in the main supplier app appear here. If they do not, the two services are pointing at different databases.

## Free plan caution

Render's free instance hours are limited per workspace. Running both the main service and this operator service all month can exceed the free allowance. If that happens, use the main service's `/admin/` path and keep this repository as the operator source or a standby deployment.

## Updating later

1. Changed screens? Run `deploy\prepare_online.bat`.
2. Run `deploy\make_live.bat`.
3. Commit and push. Render redeploys automatically.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Operator login rejected | Add the username to `ADMIN_USERNAMES`, then redeploy/restart |
| Loads created by suppliers are missing | Both services must use the same Neon `DATABASE_URL` |
| `/admin/` is 404 | Check that `backend/admin_webapp/index.html` was pushed |
| Service wakes slowly | Free Render services sleep after 15 minutes |
| Photos disappear after restart | Use `DB_TYPE=postgres` so photos are stored in the database |
