"""Convert database rows into API response objects."""

import math
from datetime import datetime

from .config import settings
from .models import Listing, Pickup, Rate, User
from .schemas import ImpactOut, ListingOut, PickupOut, RateOut, UserOut

ORG_LABELS = {
    "hotel": "Hotel",
    "restaurant": "Restaurant",
    "marriage_hall": "Marriage hall",
    "cloud_kitchen": "Cloud kitchen",
    "household": "Home",
    "other": "Other",
}


def photo_url(path: str | None) -> str | None:
    return f"/uploads/{path}" if path else None


def user_out(u: User) -> UserOut:
    return UserOut(
        id=u.id,
        username=u.username,
        name=u.name,
        role=u.role,
        org_type=u.org_type,
        phone=u.phone,
        city=u.city,
        avatar_url=photo_url(u.avatar_path),
        is_admin=u.is_admin,
    )


def distance_km(lat1: float | None, lng1: float | None, lat2: float | None, lng2: float | None) -> float | None:
    if None in (lat1, lng1, lat2, lng2):
        return None
    r = 6371.0
    p1, p2 = math.radians(float(lat1)), math.radians(float(lat2))
    dp = p2 - p1
    dl = math.radians(float(lng2) - float(lng1))
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return round(2 * r * math.asin(math.sqrt(a)), 1)


def pickup_out(p: Pickup) -> PickupOut:
    listing = p.listing
    supplier = listing.supplier
    return PickupOut(
        id=p.id,
        listing_id=p.listing_id,
        listing_title=listing.title,
        oil_type=listing.oil_type,
        city=listing.city,
        supplier_id=supplier.id,
        supplier_name=supplier.name,
        supplier_org_type=supplier.org_type,
        supplier_phone=supplier.phone,
        collector_id=p.collector_id,
        collector_name=p.collector.name,
        collector_phone=p.collector.phone,
        status=p.status,
        scheduled_at=p.scheduled_at,
        collected_at=p.collected_at,
        actual_liters=None if p.actual_liters is None else float(p.actual_liters),
        rate_per_liter=None if p.rate_per_liter is None else float(p.rate_per_liter),
        amount=None if p.amount is None else float(p.amount),
        notes=p.notes,
        rating=p.rating,
        review=p.review,
        receipt_token=p.receipt_token,
        receipt_path=f"/r/{p.receipt_token}" if p.receipt_token else None,
        created_at=p.created_at,
    )


def active_pickup(listing: Listing) -> Pickup | None:
    live = [p for p in listing.pickups if p.status != "cancelled"]
    if live:
        return live[0]  # ordered newest first by the relationship
    return listing.pickups[0] if listing.pickups else None


def listing_out(
    listing: Listing,
    viewer: User,
    now: datetime | None = None,
    my_lat: float | None = None,
    my_lng: float | None = None,
) -> ListingOut:
    now = now or datetime.now()
    pickup = active_pickup(listing)
    status = "expired" if listing.is_expired(now) else listing.status
    approx = float(listing.approx_liters or 0)
    rate = float(listing.rate_per_liter or 0)
    supplier = listing.supplier
    mine = listing.supplier_id == viewer.id
    claimable = (
        viewer.is_admin
        and not mine
        and listing.status == "open"
        and status != "expired"
    )
    collectable = (
        viewer.is_admin
        and listing.status == "claimed"
        and pickup is not None
        and pickup.collector_id == viewer.id
        and pickup.status == "scheduled"
    )
    return ListingOut(
        id=listing.id,
        supplier_id=supplier.id,
        supplier_name=supplier.name,
        supplier_org_type=supplier.org_type,
        supplier_phone=supplier.phone,
        supplier_avatar=photo_url(supplier.avatar_path),
        title=listing.title,
        oil_type=listing.oil_type,
        approx_liters=approx,
        rate_per_liter=rate,
        est_value=round(approx * rate, 2),
        photo_url=photo_url(listing.photo_path),
        address=listing.address,
        area=listing.area,
        city=listing.city,
        pincode=listing.pincode,
        lat=None if listing.lat is None else float(listing.lat),
        lng=None if listing.lng is None else float(listing.lng),
        phone=listing.phone or supplier.phone,
        available_from=listing.available_from,
        available_to=listing.available_to,
        notes=listing.notes,
        status=status,
        distance_km=distance_km(my_lat, my_lng, listing.lat, listing.lng),
        created_at=listing.created_at,
        active_pickup=pickup_out(pickup) if pickup else None,
        is_mine=mine,
        can_claim=claimable,
        can_collect=collectable,
    )


def rate_out(r: Rate) -> RateOut:
    return RateOut(oil_type=r.oil_type, price_per_liter=float(r.price_per_liter or 0), updated_at=r.updated_at)


def impact_out(liters: float, pickups: int) -> ImpactOut:
    liters = round(float(liters or 0), 2)
    co2 = round(liters * settings.co2_per_liter, 1)
    return ImpactOut(
        liters=liters,
        co2_kg=co2,
        biodiesel_l=round(liters * settings.biodiesel_yield, 1),
        car_km=round(co2 / 0.17, 1),
        pickups=pickups,
    )
