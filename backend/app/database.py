from sqlalchemy import create_engine, event, inspect, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from .config import settings


def ensure_database_exists() -> None:
    """Create the database if it is missing, so beginners don't have to."""
    if settings.is_sqlite:
        settings.sqlite_path.parent.mkdir(parents=True, exist_ok=True)
        return
    if settings.is_postgres:
        return  # the online database (Neon) is created in its website

    import pymysql

    conn = pymysql.connect(
        host=settings.db_host,
        port=settings.db_port,
        user=settings.db_user,
        password=settings.db_password,
    )
    try:
        with conn.cursor() as cur:
            cur.execute(
                f"CREATE DATABASE IF NOT EXISTS `{settings.db_name}` "
                "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
            )
        conn.commit()
    finally:
        conn.close()


ensure_database_exists()

if settings.is_sqlite:
    engine = create_engine(settings.database_url, connect_args={"check_same_thread": False})

    @event.listens_for(engine, "connect")
    def _sqlite_pragmas(dbapi_conn, _):
        dbapi_conn.execute("PRAGMA foreign_keys=ON")
elif settings.is_postgres:
    engine = create_engine(settings.database_url, pool_pre_ping=True, pool_recycle=300)
else:
    engine = create_engine(settings.database_url, pool_pre_ping=True, pool_recycle=3600)

SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# Columns added after the first version. create_all() only makes missing *tables*,
# so existing databases (your PC's SQLite, Neon online) get these added here.
_NEW_COLUMNS: dict[str, list[tuple[str, str]]] = {}


def upgrade_schema() -> None:
    insp = inspect(engine)
    with engine.begin() as conn:
        for table, columns in _NEW_COLUMNS.items():
            existing = {c["name"] for c in insp.get_columns(table)}
            for name, ddl in columns:
                if name in existing:
                    continue
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {ddl}"))

        # The old "collector" account role is retired. OilMitra operators use
        # the separate operator console and live in the `admins` table.
        conn.execute(text("UPDATE users SET role = 'supplier' WHERE role = 'collector'"))
