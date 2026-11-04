from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..admin_accounts import create_admin, find_admin
from ..database import get_db
from ..models import Admin, User
from ..schemas import OperatorCreateIn, OperatorOut
from ..security import admin_user

router = APIRouter(prefix="/admin-api", tags=["Super Admin / Operator Management"])


@router.get("/operators", response_model=list[OperatorOut])
def list_operators(db: Session = Depends(get_db), _: User = Depends(admin_user)):
    """List all registered operators from the admins table (Super Admin only)."""
    admins = db.scalars(select(Admin).order_by(Admin.created_at.desc())).all()
    return admins


@router.post("/operators", response_model=OperatorOut)
def create_new_operator(body: OperatorCreateIn, db: Session = Depends(get_db), _: User = Depends(admin_user)):
    """Provision or update an operator account (Super Admin only)."""
    try:
        admin = create_admin(
            db,
            username=body.username,
            password=body.password,
            name=body.name,
            replace=True,
        )
        return admin
    except ValueError as e:
        raise HTTPException(400, str(e))


@router.delete("/operators/{operator_id}")
def delete_operator(operator_id: int, db: Session = Depends(get_db), current: User = Depends(admin_user)):
    """Remove an operator account (Super Admin only)."""
    admin = db.get(Admin, operator_id)
    if admin is None:
        raise HTTPException(404, "Operator not found")
    if admin.username == current.username:
        raise HTTPException(400, "You cannot delete your own account while logged in")

    mirror_user = db.scalar(select(User).where(User.username == admin.username))
    if mirror_user is not None:
        mirror_user.role = "supplier"  # revoke admin privileges

    db.delete(admin)
    db.commit()
    return {"ok": True, "message": f"Operator '{admin.username}' removed"}
