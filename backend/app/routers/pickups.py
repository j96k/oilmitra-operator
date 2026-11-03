from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from ..database import get_db
from ..models import Listing, Pickup, User
from ..schemas import PickupOut, ReviewIn
from ..security import current_user
from ..serializers import pickup_out

router = APIRouter(prefix="/pickups", tags=["Pickups"])


def _visible(db: Session, user: User, pickup_id: int) -> Pickup:
    pickup = db.scalar(
        select(Pickup)
        .options(selectinload(Pickup.listing).selectinload(Listing.supplier), selectinload(Pickup.collector))
        .where(Pickup.id == pickup_id)
    )
    if pickup is None:
        raise HTTPException(404, "Pickup not found")
    if user.id not in (pickup.collector_id, pickup.listing.supplier_id) and not user.is_admin:
        raise HTTPException(404, "Pickup not found")
    return pickup


@router.get("", response_model=list[PickupOut])
def my_pickups(
    status: str | None = None,
    listing_id: int | None = None,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    stmt = (
        select(Pickup)
        .options(selectinload(Pickup.listing).selectinload(Listing.supplier), selectinload(Pickup.collector))
        .join(Listing, Listing.id == Pickup.listing_id)
    )
    stmt = stmt.where(Pickup.collector_id == user.id) if user.is_admin else stmt.where(Listing.supplier_id == user.id)
    if status:
        stmt = stmt.where(Pickup.status == status)
    if listing_id:
        stmt = stmt.where(Pickup.listing_id == listing_id)
    rows = db.scalars(stmt.order_by(Pickup.created_at.desc())).all()
    return [pickup_out(p) for p in rows]


@router.get("/{pickup_id}", response_model=PickupOut)
def get_pickup(pickup_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return pickup_out(_visible(db, user, pickup_id))


@router.post("/{pickup_id}/review", response_model=PickupOut)
def review_collector(
    pickup_id: int,
    body: ReviewIn,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """The supplier rates the OilMitra operator after a completed pickup."""
    pickup = _visible(db, user, pickup_id)
    if pickup.listing.supplier_id != user.id:
        raise HTTPException(403, "Only the supplier can leave this review")
    if pickup.status != "completed":
        raise HTTPException(400, "You can review after the pickup is completed")
    pickup.rating = body.rating
    pickup.review = (body.review or "").strip() or None
    db.commit()
    return pickup_out(pickup)
