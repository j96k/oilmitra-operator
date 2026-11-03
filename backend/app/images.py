import uuid

from fastapi import HTTPException, UploadFile
from sqlalchemy.orm import Session

from .config import settings
from .models import StoredImage

ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp", ".heic"}
MAX_IMAGE_BYTES = 10 * 1024 * 1024

_CONTENT_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".heic": "image/heic",
}


def image_content_type(name: str) -> str:
    return _CONTENT_TYPES.get("." + name.rsplit(".", 1)[-1].lower(), "application/octet-stream")


async def save_image(image: UploadFile, db: Session) -> str:
    ext = ("." + image.filename.rsplit(".", 1)[-1].lower()) if image.filename and "." in image.filename else ".jpg"
    if ext not in ALLOWED_EXT:
        raise HTTPException(400, "Only JPG, PNG, WEBP or HEIC images are allowed")
    data = await image.read()
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(400, "Image is too large (max 10 MB)")
    name = f"{uuid.uuid4().hex}{ext}"
    if settings.images_in_db:
        db.add(StoredImage(name=name, content_type=image_content_type(name), data=data))
    else:
        settings.upload_dir.mkdir(parents=True, exist_ok=True)
        (settings.upload_dir / name).write_bytes(data)
    return name


def delete_image(name: str | None, db: Session) -> None:
    """Removes the photo; the caller commits."""
    if not name:
        return
    (settings.upload_dir / name).unlink(missing_ok=True)
    stored = db.get(StoredImage, name)
    if stored is not None:
        db.delete(stored)
