from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from ..config import settings
from ..database import get_db
from ..models import Listing, Pickup, Rate, User
from ..schemas import AppConfigOut, DashboardOut, ImpactOut, LeaderRow, RateOut
from ..security import current_user
from ..serializers import impact_out, listing_out, pickup_out, rate_out
from ..seed import seed_rates

router = APIRouter(tags=["Dashboard & impact"])


def _rates(db: Session) -> list[Rate]:
    rows = {r.oil_type: r for r in db.scalars(select(Rate)).all()}
    order = ["sunflower", "mustard", "soybean", "palm", "mixed", "other"]
    return [rows[k] for k in order if k in rows]


def _completed_pickups(db: Session, user: User) -> list[Pickup]:
    """Pickups that count towards this user's impact / money.

    Operators see the whole network; a supplier only sees their own loads.
    """
    stmt = (
        select(Pickup)
        .options(selectinload(Pickup.listing).selectinload(Listing.supplier), selectinload(Pickup.collector))
        .join(Listing, Listing.id == Pickup.listing_id)
        .where(Pickup.status == "completed")
    )
    if not user.is_admin:
        stmt = stmt.where(Listing.supplier_id == user.id)
    return list(db.scalars(stmt).all())


def _month_start(now: datetime) -> datetime:
    return now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)


@router.get("/dashboard", response_model=DashboardOut)
def dashboard(
    lat: float | None = None,
    lng: float | None = None,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    now = datetime.now()
    start = _month_start(now)
    done = _completed_pickups(db, user)
    liters = sum(float(p.actual_liters or 0) for p in done)
    money = sum(float(p.amount or 0) for p in done)
    month_done = [p for p in done if p.collected_at and p.collected_at >= start]
    liters_month = sum(float(p.actual_liters or 0) for p in month_done)
    money_month = sum(float(p.amount or 0) for p in month_done)

    if user.is_admin:
        open_count = db.scalar(
            select(func.count(Listing.id)).where(
                Listing.status == "open", Listing.available_to >= now
            )
        ) or 0
        scheduled_count = db.scalar(
            select(func.count(Pickup.id)).where(Pickup.collector_id == user.id, Pickup.status == "scheduled")
        ) or 0
        peers = (
            db.scalar(
                select(func.count(User.id)).where(
                    User.role == "supplier", User.city == user.city
                )
            )
            if user.city
            else None
        )
        my_listings: list[Listing] = []
    else:
        open_count = db.scalar(
            select(func.count(Listing.id)).where(Listing.supplier_id == user.id, Listing.status == "open")
        ) or 0
        scheduled_count = db.scalar(
            select(func.count(Listing.id)).where(Listing.supplier_id == user.id, Listing.status == "claimed")
        ) or 0
        peers = (
            db.scalar(
                select(func.count(User.id)).where(
                    User.role == "supplier", User.id != user.id, User.city == user.city
                )
            )
            if user.city
            else None
        )
        my_listings = list(
            db.scalars(
                select(Listing)
                .options(selectinload(Listing.pickups), selectinload(Listing.supplier))
                .where(Listing.supplier_id == user.id)
                .order_by(Listing.created_at.desc())
                .limit(5)
            ).all()
        )
    if peers is None:
        peers = db.scalar(select(func.count(User.id)).where(User.role == "supplier")) or 0

    # Nearby open loads (nearest first when the phone sends its position).
    nearby_stmt = select(Listing).options(
        selectinload(Listing.pickups), selectinload(Listing.supplier)
    ).where(Listing.status == "open", Listing.available_to >= now)
    if not user.is_admin:
        nearby_stmt = nearby_stmt.where(Listing.supplier_id != user.id)
    nearby_rows = list(
        db.scalars(nearby_stmt.order_by(Listing.created_at.desc()).limit(40)).all()
    )
    nearby = [listing_out(x, user, now, lat, lng) for x in nearby_rows]
    if lat is not None and lng is not None:
        nearby.sort(key=lambda x: (x.distance_km is None, x.distance_km or 0))

    recent_stmt = (
        select(Pickup)
        .options(selectinload(Pickup.listing).selectinload(Listing.supplier), selectinload(Pickup.collector))
        .join(Listing, Listing.id == Pickup.listing_id)
    )
    if not user.is_admin:
        recent_stmt = recent_stmt.where(Listing.supplier_id == user.id)
    recent = list(db.scalars(recent_stmt.order_by(Pickup.created_at.desc()).limit(6)).all())

    return DashboardOut(
        role=user.role,
        name=user.name,
        city=user.city,
        impact=impact_out(liters, len(done)),
        liters_this_month=round(liters_month, 2),
        money_total=round(money, 2),
        money_this_month=round(money_month, 2),
        open_count=open_count,
        scheduled_count=scheduled_count,
        peers_nearby=peers,
        my_listings=[listing_out(x, user, now, lat, lng) for x in my_listings],
        nearby=nearby[:6],
        recent=[pickup_out(p) for p in recent],
        rates=[rate_out(r) for r in _rates(db)],
    )


@router.get("/impact", response_model=ImpactOut)
def my_impact(user: User = Depends(current_user), db: Session = Depends(get_db)):
    done = _completed_pickups(db, user)
    return impact_out(sum(float(p.actual_liters or 0) for p in done), len(done))


@router.get("/leaderboard", response_model=list[LeaderRow])
def leaderboard(db: Session = Depends(get_db)):
    liters = func.coalesce(func.sum(Pickup.actual_liters), 0)
    rows = db.execute(
        select(User, liters.label("liters"))
        .join(Listing, Listing.supplier_id == User.id)
        .join(Pickup, Pickup.listing_id == Listing.id)
        .where(Pickup.status == "completed")
        .group_by(User.id)
        .order_by(liters.desc())
        .limit(10)
    ).all()
    return [
        LeaderRow(
            rank=i + 1,
            name=u.name,
            org_type=u.org_type,
            city=u.city,
            avatar_url=f"/uploads/{u.avatar_path}" if u.avatar_path else None,
            liters=round(float(total or 0), 2),
        )
        for i, (u, total) in enumerate(rows)
    ]


@router.get("/rates", response_model=list[RateOut])
def rates(db: Session = Depends(get_db)):
    seed_rates(db)
    return [rate_out(r) for r in _rates(db)]


@router.get("/app-config", response_model=AppConfigOut)
def app_config(db: Session = Depends(get_db)):
    seed_rates(db)
    return AppConfigOut(
        app_name="OilMitra",
        tagline="Used oil. Real value. Picked up.",
        co2_per_liter=settings.co2_per_liter,
        biodiesel_yield=settings.biodiesel_yield,
        rates=[rate_out(r) for r in _rates(db)],
    )
