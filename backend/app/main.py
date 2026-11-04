from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session

from . import models  # noqa: F401  (registers tables)
from .admin_accounts import sync_all_admins
from .config import BASE_DIR, settings
from .database import Base, SessionLocal, engine, get_db, upgrade_schema
from .models import StoredImage
from .routers import admin_portal, auth, dashboard, geo, listings, pickups, public
from .seed import seed_rates

Base.metadata.create_all(bind=engine)  # creates tables on first run
upgrade_schema()  # adds columns introduced later (keeps existing data)
settings.upload_dir.mkdir(parents=True, exist_ok=True)

with SessionLocal() as _db:
    seed_rates(_db)
    sync_all_admins(_db)  # every admins row gets a users mirror row

app = FastAPI(title="OilMitra API", version="1.0.0", description="Used cooking oil pickup network")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

app.include_router(auth.router)
app.include_router(admin_portal.router)
app.include_router(listings.router)
app.include_router(pickups.router)
app.include_router(dashboard.router)
app.include_router(public.rates_router)
app.include_router(public.public_router)
app.include_router(geo.router)


@app.get("/uploads/{name}", tags=["Photos"])
def get_photo(name: str, db: Session = Depends(get_db)):
    """A photo: from backend/uploads/ on disk, or from the database when it's online."""
    if "/" in name or "\\" in name or name.startswith("."):
        raise HTTPException(404)
    path = settings.upload_dir / name
    if path.is_file():
        return FileResponse(path)
    stored = db.get(StoredImage, name)
    if stored is None:
        raise HTTPException(404, "Photo not found")
    return Response(stored.data, media_type=stored.content_type, headers={"Cache-Control": "public, max-age=31536000"})


# The browser versions of the apps are served by the API server:
#   /app/    supplier app (OilMitra)
#   /admin/  operator console (OilMitra Operators)
#   /portal/ super admin portal (myOilMitra)
_web_apps = {
    "/app": (BASE_DIR / "webapp", BASE_DIR.parent / "mobile" / "build" / "web"),
    "/admin": (BASE_DIR / "admin_webapp", BASE_DIR.parent / "mobile" / "build" / "admin_web"),
    "/portal": (BASE_DIR / "portal_webapp", BASE_DIR.parent / "mobile" / "build" / "portal_web"),
}
for mount_path, candidates in _web_apps.items():
    for web_dir in candidates:
        if (web_dir / "index.html").exists():
            app.mount(mount_path, StaticFiles(directory=web_dir, html=True), name=mount_path.strip("/"))
            break


@app.get("/", tags=["Health"])
def health():
    return {
        "status": "ok",
        "app": "OilMitra",
        "message": "Used cooking oil pickup API is running. Open /docs to try it.",
    }
