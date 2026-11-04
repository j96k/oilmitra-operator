from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, LargeBinary, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base

ROLES = ("supplier", "admin")
ORG_TYPES = ("hotel", "restaurant", "marriage_hall", "cloud_kitchen", "household", "other")
OIL_TYPES = ("sunflower", "mustard", "soybean", "palm", "mixed", "other")
LISTING_STATUSES = ("open", "claimed", "collected", "cancelled")
PICKUP_STATUSES = ("scheduled", "completed", "cancelled")


class User(Base):
    """An account: a supplier who has oil, or an OilMitra admin/operator."""

    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    name: Mapped[str] = mapped_column(String(120))  # shop / hotel / person name
    role: Mapped[str] = mapped_column(String(20), default="supplier")  # supplier | admin
    org_type: Mapped[str] = mapped_column(String(30), default="other")  # hotel | restaurant | ...
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    city: Mapped[str | None] = mapped_column(String(80), nullable=True, index=True)
    avatar_path: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, server_default=func.now())

    listings: Mapped[list["Listing"]] = relationship(back_populates="supplier", cascade="all, delete-orphan")
    pickups: Mapped[list["Pickup"]] = relationship(back_populates="collector", cascade="all, delete-orphan")

    @property
    def is_admin(self) -> bool:
        # Admin rights now come only from the database: a users row with
        # role="admin", which is created automatically for every row in the
        # admins table. ADMIN_USERNAMES is no longer used.
        return self.role == "admin"


class Admin(Base):
    """An OilMitra operator account.

    These rows are created by hand by the owner (see
    ``backend/scripts/create_admin.py``), never through the apps. They are the
    only accounts that can sign in at /admin/ and the only source of admin
    passwords.
    """

    __tablename__ = "admins"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    name: Mapped[str] = mapped_column(String(120), default="OilMitra operator")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, server_default=func.now())


class Listing(Base):
    """A load of used cooking oil offered for pickup."""

    __tablename__ = "listings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    supplier_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(120))
    oil_type: Mapped[str] = mapped_column(String(30), default="mixed")
    approx_liters: Mapped[float] = mapped_column(Numeric(8, 2), default=0)
    rate_per_liter: Mapped[float] = mapped_column(Numeric(8, 2), default=0)
    photo_path: Mapped[str | None] = mapped_column(String(255), nullable=True)

    address: Mapped[str] = mapped_column(Text, default="")
    area: Mapped[str | None] = mapped_column(String(120), nullable=True)
    city: Mapped[str | None] = mapped_column(String(80), nullable=True, index=True)
    pincode: Mapped[str | None] = mapped_column(String(12), nullable=True)
    lat: Mapped[float | None] = mapped_column(Numeric(10, 7), nullable=True)
    lng: Mapped[float | None] = mapped_column(Numeric(10, 7), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)

    available_from: Mapped[datetime] = mapped_column(DateTime, index=True)
    available_to: Mapped[datetime] = mapped_column(DateTime, index=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="open", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, server_default=func.now())

    supplier: Mapped[User] = relationship(back_populates="listings")
    pickups: Mapped[list["Pickup"]] = relationship(
        back_populates="listing", cascade="all, delete-orphan", order_by="Pickup.created_at.desc()"
    )

    def is_expired(self, now: datetime) -> bool:
        return self.status == "open" and self.available_to < now


class Pickup(Base):
    """An OilMitra operator claiming a listing, then recording what was collected."""

    __tablename__ = "pickups"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    listing_id: Mapped[int] = mapped_column(ForeignKey("listings.id", ondelete="CASCADE"), index=True)
    collector_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    status: Mapped[str] = mapped_column(String(20), default="scheduled")  # scheduled | completed | cancelled

    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    collected_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    actual_liters: Mapped[float | None] = mapped_column(Numeric(8, 2), nullable=True)
    rate_per_liter: Mapped[float | None] = mapped_column(Numeric(8, 2), nullable=True)
    amount: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    rating: Mapped[int | None] = mapped_column(Integer, nullable=True)  # supplier rates the operator 1..5
    review: Mapped[str | None] = mapped_column(Text, nullable=True)
    receipt_token: Mapped[str | None] = mapped_column(String(40), nullable=True, unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, server_default=func.now())

    listing: Mapped[Listing] = relationship(back_populates="pickups")
    collector: Mapped[User] = relationship(back_populates="pickups")

    @property
    def supplier(self) -> User:
        return self.listing.supplier


class Rate(Base):
    """The day's buying rate for each kind of used oil (admin editable)."""

    __tablename__ = "rates"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    oil_type: Mapped[str] = mapped_column(String(30), unique=True)
    price_per_liter: Mapped[float] = mapped_column(Numeric(8, 2), default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, server_default=func.now())


class StoredImage(Base):
    """A photo kept inside the database (used with an online database,
    because free hosting disks are wiped on restart)."""

    __tablename__ = "images"

    name: Mapped[str] = mapped_column(String(64), primary_key=True)
    content_type: Mapped[str] = mapped_column(String(40))
    data: Mapped[bytes] = mapped_column(LargeBinary)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, server_default=func.now())
