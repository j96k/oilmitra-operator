from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..images import delete_image, save_image
from ..models import User
from ..schemas import LoginIn, ProfileIn, RegisterIn, TokenOut, UserOut
from ..security import create_token, current_user, hash_password, verify_password
from ..serializers import user_out

router = APIRouter(prefix="/auth", tags=["Login"])


@router.post("/register", response_model=TokenOut)
def register(body: RegisterIn, db: Session = Depends(get_db)):
    username = body.username.lower()
    if db.scalar(select(User).where(User.username == username)):
        raise HTTPException(400, "This username is already taken")
    user = User(
        username=username,
        password_hash=hash_password(body.password),
        name=body.name.strip(),
        role="admin" if username in settings.admins else "supplier",
        org_type=body.org_type,
        phone=(body.phone or "").strip() or None,
        city=(body.city or "").strip() or None,
    )
    db.add(user)
    db.commit()
    return TokenOut(access_token=create_token(user.id), user=user_out(user))


@router.post("/login", response_model=TokenOut)
def login(body: LoginIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.username == body.username.lower().strip()))
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(401, "Wrong username or password")
    # Keep existing accounts consistent with the current role model:
    # ADMIN_USERNAMES -> admin, and the retired collector role -> supplier.
    expected = "admin" if user.username.lower() in settings.admins else "supplier"
    if user.role != expected:
        user.role = expected
        db.commit()
    return TokenOut(access_token=create_token(user.id), user=user_out(user))


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(current_user)):
    return user_out(user)


@router.put("/me", response_model=UserOut)
def update_me(body: ProfileIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    if body.name is not None:
        user.name = body.name.strip()
    if body.org_type is not None:
        user.org_type = body.org_type
    if body.phone is not None:
        user.phone = body.phone.strip() or None
    if body.city is not None:
        user.city = body.city.strip() or None
    db.commit()
    return user_out(user)


@router.post("/me/avatar", response_model=UserOut)
async def upload_avatar(
    image: UploadFile = File(...),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    old = user.avatar_path
    user.avatar_path = await save_image(image, db)
    delete_image(old, db)
    db.commit()
    return user_out(user)
