from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    """All settings are read from backend/.env (see .env.example)."""

    # "sqlite"   = one file (backend/database/oil_mitra.db), no server needed.
    # "mysql"    = a MySQL server, using the db_* values below.
    # "postgres" = an online PostgreSQL (e.g. Neon), using DATABASE_URL.
    db_type: str = "sqlite"
    # Full connection string, e.g. postgresql://user:pass@host/db?sslmode=require
    db_url: str = Field("", validation_alias="DATABASE_URL")
    sqlite_path: Path = BASE_DIR / "database" / "oil_mitra.db"

    db_host: str = "127.0.0.1"
    db_port: int = 3306
    db_user: str = "root"
    db_password: str = ""
    db_name: str = "oil_mitra_db"

    jwt_secret: str = "change-me-to-a-long-random-string"
    jwt_expire_days: int = 30

    # The free app can show a small "support us" pop-up. Empty = hidden.
    donate_upi_id: str = ""
    donate_name: str = "OilMitra"
    donate_url: str = ""

    # Retired. Admin/operator accounts now live in the `admins` table and are
    # created with backend/scripts/create_admin.py. Kept so old .env files load.
    admin_usernames: str = ""

    # Google Maps key. Geocoding (server), the web Maps JavaScript API
    # (served from /geo/config), and the Android/iOS SDK key at build time.
    google_maps_api_key: str = ""

    # --- Impact maths (shown in the app) ---
    # Approximate CO2e avoided per litre of used cooking oil diverted from drains.
    co2_per_liter: float = 2.8
    # Litres of biodiesel that roughly come out of one litre of used oil.
    biodiesel_yield: float = 0.92

    upload_dir: Path = BASE_DIR / "uploads"

    model_config = SettingsConfigDict(env_file=BASE_DIR / ".env", extra="ignore")

    @property
    def admins(self) -> set[str]:
        return {u.strip().lower() for u in self.admin_usernames.split(",") if u.strip()}

    @property
    def is_postgres(self) -> bool:
        return self.db_type.strip().lower() in ("postgres", "postgresql")

    @property
    def is_sqlite(self) -> bool:
        return self.db_type.strip().lower() == "sqlite"

    @property
    def images_in_db(self) -> bool:
        # Online hosts (like Render's free plan) wipe their disk on restart,
        # so with an online database the photos are stored in it too.
        return self.is_postgres

    @property
    def database_url(self) -> str:
        from urllib.parse import quote_plus

        if self.is_postgres:
            url = self.db_url.strip()
            if not url:
                raise RuntimeError("DB_TYPE=postgres needs DATABASE_URL (copy it from Neon)")
            for prefix in ("postgresql://", "postgres://"):
                if url.startswith(prefix):
                    url = "postgresql+psycopg://" + url[len(prefix):]
            return url
        if self.is_sqlite:
            return f"sqlite:///{self.sqlite_path.as_posix()}"
        return (
            f"mysql+pymysql://{self.db_user}:{quote_plus(self.db_password)}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}?charset=utf8mb4"
        )


settings = Settings()
