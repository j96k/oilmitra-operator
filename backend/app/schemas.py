from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator


# ---------- Auth ----------
class RegisterIn(BaseModel):
    username: str = Field(min_length=3, max_length=50, pattern=r"^[a-zA-Z0-9_.]+$")
    password: str = Field(min_length=6, max_length=72)
    name: str = Field(min_length=2, max_length=120)
    role: str = Field(default="supplier", pattern=r"^supplier$")
    org_type: str = Field(default="other", pattern=r"^(hotel|restaurant|marriage_hall|cloud_kitchen|household|other)$")
    phone: str | None = Field(default=None, max_length=20)
    city: str | None = Field(default=None, max_length=80)


class LoginIn(BaseModel):
    username: str
    password: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    username: str
    name: str
    role: str
    org_type: str
    phone: str | None
    city: str | None
    avatar_url: str | None = None
    is_admin: bool = False


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class ProfileIn(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    org_type: str | None = Field(default=None, pattern=r"^(hotel|restaurant|marriage_hall|cloud_kitchen|household|other)$")
    phone: str | None = Field(default=None, max_length=20)
    city: str | None = Field(default=None, max_length=80)


# ---------- Listings ----------
class ListingIn(BaseModel):
    title: str = Field(min_length=2, max_length=120)
    oil_type: str = Field(default="mixed", pattern=r"^(sunflower|mustard|soybean|palm|mixed|other)$")
    approx_liters: float = Field(gt=0, le=100000)
    rate_per_liter: float = Field(default=0, ge=0, le=100000)
    address: str = Field(min_length=4, max_length=500)
    area: str | None = Field(default=None, max_length=120)
    city: str | None = Field(default=None, max_length=80)
    pincode: str | None = Field(default=None, max_length=12)
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)
    phone: str | None = Field(default=None, max_length=20)
    available_from: datetime
    available_to: datetime
    notes: str | None = Field(default=None, max_length=1000)

    @model_validator(mode="after")
    def tidy(self):
        if self.available_to <= self.available_from:
            raise ValueError("The pickup window must end after it starts")
        for f in ("area", "city", "pincode", "phone", "notes"):
            v = getattr(self, f)
            setattr(self, f, v.strip() if v and v.strip() else None)
        return self


class ClaimIn(BaseModel):
    scheduled_at: datetime | None = None
    note: str | None = Field(default=None, max_length=300)


class CollectIn(BaseModel):
    actual_liters: float = Field(gt=0, le=100000)
    rate_per_liter: float = Field(default=0, ge=0, le=100000)
    notes: str | None = Field(default=None, max_length=1000)


class ReviewIn(BaseModel):
    rating: int = Field(ge=1, le=5)
    review: str | None = Field(default=None, max_length=500)


class PickupOut(BaseModel):
    id: int
    listing_id: int
    listing_title: str
    oil_type: str
    city: str | None
    supplier_id: int
    supplier_name: str
    supplier_org_type: str
    supplier_phone: str | None
    collector_id: int
    collector_name: str
    collector_phone: str | None
    status: str
    scheduled_at: datetime | None
    collected_at: datetime | None
    actual_liters: float | None
    rate_per_liter: float | None
    amount: float | None
    notes: str | None
    rating: int | None
    review: str | None
    receipt_token: str | None
    receipt_path: str | None
    created_at: datetime


class ListingOut(BaseModel):
    id: int
    supplier_id: int
    supplier_name: str
    supplier_org_type: str
    supplier_phone: str | None
    supplier_avatar: str | None
    title: str
    oil_type: str
    approx_liters: float
    rate_per_liter: float
    est_value: float
    photo_url: str | None
    address: str
    area: str | None
    city: str | None
    pincode: str | None
    lat: float | None
    lng: float | None
    phone: str | None
    available_from: datetime
    available_to: datetime
    notes: str | None
    status: str  # open | claimed | collected | cancelled | expired
    distance_km: float | None
    created_at: datetime
    active_pickup: PickupOut | None
    is_mine: bool
    can_claim: bool
    can_collect: bool


# ---------- Rates / impact ----------
class RateOut(BaseModel):
    oil_type: str
    price_per_liter: float
    updated_at: datetime


class RateIn(BaseModel):
    price_per_liter: float = Field(ge=0, le=100000)


class ImpactOut(BaseModel):
    liters: float
    co2_kg: float
    biodiesel_l: float
    car_km: float
    pickups: int


class LeaderRow(BaseModel):
    rank: int
    name: str
    org_type: str
    city: str | None
    avatar_url: str | None
    liters: float


class DashboardOut(BaseModel):
    role: str
    name: str
    city: str | None
    impact: ImpactOut
    liters_this_month: float
    money_total: float  # earned (supplier) or spent (admin/operator)
    money_this_month: float
    open_count: int
    scheduled_count: int
    peers_nearby: int  # suppliers nearby (admin) or suppliers in my city (supplier)
    my_listings: list[ListingOut]
    nearby: list[ListingOut]
    recent: list[PickupOut]
    rates: list[RateOut]


class AppConfigOut(BaseModel):
    app_name: str
    tagline: str
    co2_per_liter: float
    biodiesel_yield: float
    rates: list[RateOut]


# ---------- Public receipt ----------
class ReceiptOut(BaseModel):
    receipt_no: str
    collected_at: datetime | None
    supplier_name: str
    supplier_org_type: str
    collector_name: str
    title: str
    oil_type: str
    liters: float
    rate_per_liter: float
    amount: float
    city: str | None
    co2_kg: float
    biodiesel_l: float


# ---------- Operator management (myOilMitra) ----------
class OperatorOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    username: str
    name: str
    created_at: datetime | None = None


class OperatorCreateIn(BaseModel):
    username: str = Field(min_length=3, max_length=50, pattern=r"^[a-zA-Z0-9_.]+$")
    password: str = Field(min_length=6, max_length=72)
    name: str = Field(min_length=2, max_length=120)

