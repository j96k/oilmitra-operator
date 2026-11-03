# OilMitra Operator

The dedicated operator console for **OilMitra**, the used-cooking-oil pickup network.

Operators use this app to claim open loads, plan pickups, record collected litres and rates, contact suppliers, share receipts, and manage every listing across the network.

## Live app

| App | URL on your deployment |
| --- | --- |
| Operator console | `https://YOUR-OPERATOR-SERVICE.onrender.com/admin/` |
| API docs | `https://YOUR-OPERATOR-SERVICE.onrender.com/docs` |

The supplier app lives in the separate `oilmitra` repository.

## Shared data

This service is designed to use the **same PostgreSQL database** as the main OilMitra service. Both apps then see the same suppliers, loads, pickups, and receipts.

- Use the same `DATABASE_URL` (Neon connection string) in both Render services.
- Set the same `ADMIN_USERNAMES` value in both.
- Do **not** create a second database unless you deliberately want separate data.

The main `oilmitra` repository already serves the operator console at `/admin/`. Deploying this repository separately is optional and gives operators their own URL.

## What's inside

```
oilmitra-operator/
├── backend/          FastAPI + SQLAlchemy API
│   ├── app/          application code
│   ├── tests/        end-to-end smoke test
│   ├── admin_webapp/ prebuilt operator app served at /admin/
│   ├── .env.example  configuration template
│   └── run_server.bat
├── mobile/           Flutter source
│   └── lib/main_admin.dart  operator app entry point
├── deploy/           online guide and build scripts
└── render.yaml       Render blueprint
```

## Operator access

Only accounts with `is_admin` may use this console. An account is an operator when:

1. Its stored role is `admin`, or
2. Its username is listed in `ADMIN_USERNAMES`.

On a fresh database:

1. Set `ADMIN_USERNAMES` to the operator username(s) before deploying.
2. Open `/admin/` and choose **Create operator**.
3. Register with a provisioned username and a strong password.
4. Sign in.

Supplier accounts are rejected by the console and logged out.

## Quick start on this PC

```powershell
cd backend
.\run_server.bat
```

Then open <http://localhost:8000/admin/>.

The prebuilt operator app in `backend/admin_webapp/` works without Flutter. To rebuild after changing screens:

```powershell
cd mobile
.\run_web_admin.bat
```

## Deploy online

See **[deploy/ONLINE_GUIDE.md](deploy/ONLINE_GUIDE.md)**.

Short version:

1. Create or reuse the Neon PostgreSQL database from the main OilMitra deployment.
2. Push this folder to a GitHub repository named `oilmitra-operator`.
3. On Render, create a **Blueprint** from the repository.
4. Paste the **same** Neon connection string for `DATABASE_URL`.
5. Set `ADMIN_USERNAMES`.
6. Open `/admin/`.

## Configuration

| Variable | Purpose |
| --- | --- |
| `DB_TYPE` | Use `postgres` online |
| `DATABASE_URL` | Neon PostgreSQL connection string |
| `JWT_SECRET` | Long random string used to sign login tokens |
| `JWT_EXPIRE_DAYS` | Login lifetime in days (default 30) |
| `ADMIN_USERNAMES` | Comma-separated operator usernames |
| `DONATE_UPI_ID`, `DONATE_NAME`, `DONATE_URL` | Optional support pop-up |
| `CO2_PER_LITER` | CO₂e avoided per litre (default 2.8) |
| `BIODIESEL_YIELD` | Biodiesel yield per litre (default 0.92) |

Never commit a real `.env`, database file, or Neon connection string.

## Tests

```powershell
cd backend
.\.venv\Scripts\python.exe tests\smoke_test.py http://127.0.0.1:8000
```

Flutter checks:

```powershell
cd mobile
flutter analyze
flutter test
```

## License

Add your preferred license before publishing publicly. No license file is included yet.
