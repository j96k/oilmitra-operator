from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import OIL_TYPES, Rate

# Sensible starting rates (₹ / litre). The admin can change them from the app.
DEFAULT_RATES = {
    "sunflower": 52.0,
    "mustard": 58.0,
    "soybean": 50.0,
    "palm": 45.0,
    "mixed": 48.0,
    "other": 40.0,
}


def seed_rates(db: Session) -> None:
    have = {r.oil_type for r in db.scalars(select(Rate)).all()}
    for oil in OIL_TYPES:
        if oil not in have:
            db.add(Rate(oil_type=oil, price_per_liter=DEFAULT_RATES.get(oil, 40.0), updated_at=datetime.now()))
    db.commit()
