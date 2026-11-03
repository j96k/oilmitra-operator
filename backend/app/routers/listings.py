import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy import or_, select
from sqlalchemy.orm import Session, selectinload

from ..database import get_db
from ..images import delete_image, save_image
from ..models import Listing, Pickup, User
from ..schemas import ClaimIn, CollectIn, ListingIn, ListingOut, PickupOut
from ..security import current_user
from ..serializers import listing_out, pickup_out

router = APIRouter(prefix="/listings", tags=["Oil listings"])


def _get(db: Session, listing_id: int) -> Listing:
    listing = db.scalar(
        select(Listing)
        .options(selectinload(Listing.pickups), selectinload(Listing.supplier))
        .where(Listing.id == listing_id)
    )
    if listing is None:
        raise HTTPException(404, "Listing not found")
    return listing


def _form_body(**kw) -> ListingIn:
    return ListingIn(**kw)


@router.get("", response_model=list[ListingOut])
def list_listings(
    q: str | None = None,
    status: str | None = None,
    mine: bool = False,
    assigned: bool = False,
    scope: str | None = None,
    lat: float | None = None,
    lng: float | None = None,
    radius_km: float | None = None,
    limit: int = 60,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Browse oil. Default = open loads from other suppliers, nearest first when lat/lng are sent.

    Operators can send ``scope=all`` to manage every load, including claimed,
    collected, cancelled and expired ones.
    """
    now = datetime.now()
    show_all = scope == "all" and user.is_admin
    stmt = select(Listing).options(selectinload(Listing.pickups), selectinload(Listing.supplier))
    if mine:
        stmt = stmt.where(Listing.supplier_id == user.id)
    elif assigned:
        stmt = stmt.where(Listing.pickups.any(Pickup.collector_id == user.id))
    else:
        stmt = stmt.where(Listing.supplier_id != user.id)
    if status == "expired":
        stmt = stmt.where(Listing.status == "open", Listing.available_to < now)
    elif status:
        stmt = stmt.where(Listing.status == status)
    elif not (mine or assigned) and not show_all:
        stmt = stmt.where(Listing.status == "open", Listing.available_to >= now)
    if q:
        like = f"%{q.strip()}%"
        stmt = stmt.where(
            or_(
                Listing.title.ilike(like),
                Listing.address.ilike(like),
                Listing.area.ilike(like),
                Listing.city.ilike(like),
                Listing.oil_type.ilike(like),
            )
        )
    items = [listing_out(x, user, now, lat, lng) for x in db.scalars(stmt).all()]
    if radius_km is not None and lat is not None and lng is not None:
        items = [x for x in items if x.distance_km is not None and x.distance_km <= radius_km]
    if lat is not None and lng is not None:
        items.sort(key=lambda x: (x.distance_km is None, x.distance_km or 0))
    else:
        items.sort(key=lambda x: x.created_at, reverse=True)
    return items[: max(1, min(limit, 200))]


@router.get("/{listing_id}", response_model=ListingOut)
def get_listing(
    listing_id: int,
    lat: float | None = None,
    lng: float | None = None,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    return listing_out(_get(db, listing_id), user, datetime.now(), lat, lng)


@router.post("", response_model=ListingOut)
async def create_listing(
    title: str = Form(...),
    oil_type: str = Form("mixed"),
    approx_liters: float = Form(...),
    rate_per_liter: float = Form(0),
    address: str = Form(...),
    area: str | None = Form(None),
    city: str | None = Form(None),
    pincode: str | None = Form(None),
    lat: float | None = Form(None),
    lng: float | None = Form(None),
    phone: str | None = Form(None),
    available_from: datetime = Form(...),
    available_to: datetime = Form(...),
    notes: str | None = Form(None),
    photo: UploadFile | None = File(None),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    body = _form_body(
        title=title, oil_type=oil_type, approx_liters=approx_liters, rate_per_liter=rate_per_liter,
        address=address, area=area, city=city, pincode=pincode, lat=lat, lng=lng, phone=phone,
        available_from=available_from, available_to=available_to, notes=notes,
    )
    listing = Listing(supplier_id=user.id, **body.model_dump())
    if photo is not None and photo.filename:
        listing.photo_path = await save_image(photo, db)
    db.add(listing)
    db.commit()
    return listing_out(_get(db, listing.id), user, datetime.now(), lat, lng)


@router.put("/{listing_id}", response_model=ListingOut)
async def update_listing(
    listing_id: int,
    title: str = Form(...),
    oil_type: str = Form("mixed"),
    approx_liters: float = Form(...),
    rate_per_liter: float = Form(0),
    address: str = Form(...),
    area: str | None = Form(None),
    city: str | None = Form(None),
    pincode: str | None = Form(None),
    lat: float | None = Form(None),
    lng: float | None = Form(None),
    phone: str | None = Form(None),
    available_from: datetime = Form(...),
    available_to: datetime = Form(...),
    notes: str | None = Form(None),
    photo: UploadFile | None = File(None),
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    listing = _get(db, listing_id)
    if listing.supplier_id != user.id:
        raise HTTPException(403, "This is not your listing")
    if listing.status in ("collected", "cancelled"):
        raise HTTPException(400, "This listing is finished and can't be edited")
    body = _form_body(
        title=title, oil_type=oil_type, approx_liters=approx_liters, rate_per_liter=rate_per_liter,
        address=address, area=area, city=city, pincode=pincode, lat=lat, lng=lng, phone=phone,
        available_from=available_from, available_to=available_to, notes=notes,
    )
    for key, value in body.model_dump().items():
        setattr(listing, key, value)
    if photo is not None and photo.filename:
        old = listing.photo_path
        listing.photo_path = await save_image(photo, db)
        delete_image(old, db)
    db.commit()
    return listing_out(_get(db, listing.id), user, datetime.now())


@router.delete("/{listing_id}")
def delete_listing(listing_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    listing = _get(db, listing_id)
    if listing.supplier_id != user.id and not user.is_admin:
        raise HTTPException(403, "This is not your listing")
    if any(p.status == "completed" for p in listing.pickups):
        raise HTTPException(400, "This load was already collected — keep it for your records")
    photo = listing.photo_path
    db.delete(listing)
    delete_image(photo, db)
    db.commit()
    return {"ok": True}


@router.post("/{listing_id}/claim", response_model=PickupOut)
def claim_listing(
    listing_id: int,
    body: ClaimIn,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """An OilMitra operator takes this pickup. The load is held for them."""
    if not user.is_admin:
        raise HTTPException(403, "Only the OilMitra admin app can claim pickups")
    listing = _get(db, listing_id)
    if listing.supplier_id == user.id:
        raise HTTPException(400, "This is your own listing")
    if listing.status != "open" or listing.is_expired(datetime.now()):
        raise HTTPException(400, "This load is no longer available")
    pickup = Pickup(
        listing_id=listing.id,
        collector_id=user.id,
        status="scheduled",
        scheduled_at=body.scheduled_at or listing.available_from,
        notes=(body.note or "").strip() or None,
    )
    listing.status = "claimed"
    db.add(pickup)
    db.commit()
    return pickup_out(pickup)


@router.post("/{listing_id}/release", response_model=ListingOut)
def release_listing(listing_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """The operator can't make it — put the load back on the radar."""
    listing = _get(db, listing_id)
    pickup = next(
        (p for p in listing.pickups if p.collector_id == user.id and p.status == "scheduled"), None
    )
    if pickup is None:
        raise HTTPException(404, "You have no scheduled pickup on this load")
    pickup.status = "cancelled"
    listing.status = "open"
    db.commit()
    return listing_out(listing, user, datetime.now())


@router.post("/{listing_id}/collect", response_model=PickupOut)
def collect_listing(
    listing_id: int,
    body: CollectIn,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    """Record the real litres and rate at pickup. Creates the digital receipt."""
    listing = _get(db, listing_id)
    pickup = next(
        (p for p in listing.pickups if p.collector_id == user.id and p.status == "scheduled"), None
    )
    if pickup is None:
        raise HTTPException(404, "You have no scheduled pickup on this load")
    amount = round(body.actual_liters * body.rate_per_liter, 2)
    pickup.status = "completed"
    pickup.collected_at = datetime.now()
    pickup.actual_liters = body.actual_liters
    pickup.rate_per_liter = body.rate_per_liter
    pickup.amount = amount
    pickup.notes = (body.notes or "").strip() or None
    pickup.receipt_token = uuid.uuid4().hex[:20]
    listing.status = "collected"
    db.commit()
    return pickup_out(pickup)


@router.post("/{listing_id}/cancel", response_model=ListingOut)
def cancel_listing(listing_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    listing = _get(db, listing_id)
    if listing.supplier_id != user.id and not user.is_admin:
        raise HTTPException(403, "This is not your listing")
    if listing.status == "collected":
        raise HTTPException(400, "This load was already collected")
    listing.status = "cancelled"
    for p in listing.pickups:
        if p.status == "scheduled":
            p.status = "cancelled"
    db.commit()
    return listing_out(listing, user, datetime.now())
