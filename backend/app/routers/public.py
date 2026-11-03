import html
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from ..database import get_db
from ..models import Listing, Pickup, Rate
from ..schemas import RateIn, RateOut, ReceiptOut
from ..security import admin_user
from ..serializers import ORG_LABELS, rate_out

# ---- Public receipt (no login — the operator or supplier can share this link) ----
public_router = APIRouter(tags=["Public receipt"])

# ---- Rate board (admin only) ----
rates_router = APIRouter(prefix="/rates", tags=["Rate board"])

_OIL_LABEL = {
    "sunflower": "Sunflower oil",
    "mustard": "Mustard oil",
    "soybean": "Soybean oil",
    "palm": "Palm oil",
    "mixed": "Mixed oil",
    "other": "Other oil",
}


def _receipt(db: Session, token: str) -> tuple[Pickup, float, float]:
    pickup = db.scalar(
        select(Pickup)
        .options(selectinload(Pickup.listing).selectinload(Listing.supplier), selectinload(Pickup.collector))
        .where(Pickup.receipt_token == token, Pickup.status == "completed")
    )
    if pickup is None:
        raise HTTPException(404, "Receipt not found")
    from ..config import settings

    liters = float(pickup.actual_liters or 0)
    return pickup, liters * settings.co2_per_liter, liters * settings.biodiesel_yield


@public_router.get("/public/receipts/{token}", response_model=ReceiptOut)
def receipt_json(token: str, db: Session = Depends(get_db)):
    p, co2, bio = _receipt(db, token)
    listing = p.listing
    return ReceiptOut(
        receipt_no=p.receipt_token or "",
        collected_at=p.collected_at,
        supplier_name=listing.supplier.name,
        supplier_org_type=listing.supplier.org_type,
        collector_name=p.collector.name,
        title=listing.title,
        oil_type=listing.oil_type,
        liters=float(p.actual_liters or 0),
        rate_per_liter=float(p.rate_per_liter or 0),
        amount=float(p.amount or 0),
        city=listing.city,
        co2_kg=round(co2, 1),
        biodiesel_l=round(bio, 1),
    )


@public_router.get("/r/{token}", response_class=HTMLResponse, include_in_schema=False)
def receipt_page(token: str, db: Session = Depends(get_db)):
    """A tiny, print-friendly receipt page for WhatsApp sharing (no app install needed)."""
    try:
        p, co2, bio = _receipt(db, token)
    except HTTPException:
        return HTMLResponse(_not_found(), status_code=404)
    listing = p.listing
    e = html.escape
    when = (p.collected_at or datetime.now()).strftime("%d %b %Y, %I:%M %p")
    rows = [
        ("Oil", _OIL_LABEL.get(listing.oil_type, listing.oil_type)),
        ("Quantity", f"{float(p.actual_liters or 0):g} L"),
        ("Rate", f"\u20b9{float(p.rate_per_liter or 0):g} / litre"),
        ("Supplier", f"{e(listing.supplier.name)} \u00b7 {e(ORG_LABELS.get(listing.supplier.org_type, 'Other'))}"),
        ("Collected by", e(p.collector.name)),
        ("Place", e(", ".join(x for x in [listing.area, listing.city] if x) or listing.address)),
    ]
    row_html = "".join(f"<tr><th>{e(a)}</th><td>{b}</td></tr>" for a, b in rows)
    return HTMLResponse(f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>OilMitra receipt {e(token)}</title>
<style>
  *{{box-sizing:border-box}} body{{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;
    background:#10150f;color:#1d2118;display:flex;justify-content:center;padding:24px 14px}}
  .card{{background:#fffdf6;max-width:430px;width:100%;border-radius:28px;padding:26px;
    box-shadow:0 30px 80px rgba(0,0,0,.45)}}
  .brand{{display:flex;align-items:center;gap:10px;font-weight:800;letter-spacing:-.3px;font-size:20px}}
  .drop{{width:34px;height:34px;border-radius:50% 50% 50% 4px;transform:rotate(45deg);
    background:linear-gradient(145deg,#ffd166,#e08a1e)}}
  .muted{{color:#727a68;font-size:13px}}
  .amount{{font-size:42px;font-weight:800;letter-spacing:-1.5px;margin:18px 0 2px}}
  .litres{{font-size:15px;color:#3f4a37}}
  table{{width:100%;border-collapse:collapse;margin-top:20px;font-size:14px}}
  th{{text-align:left;color:#8a907e;font-weight:600;padding:8px 0;width:40%}}
  td{{padding:8px 0;text-align:right;font-weight:600}}
  tr+tr{{border-top:1px dashed #e6e2d4}}
  .impact{{margin-top:22px;background:#eef5df;border-radius:18px;padding:14px 16px;font-size:13px;color:#3d5220}}
  .impact b{{font-size:20px;display:block;letter-spacing:-.5px}}
  .foot{{margin-top:22px;font-size:11px;color:#9aa08f;text-align:center;line-height:1.5}}
  @media print{{body{{background:#fff;padding:0}} .card{{box-shadow:none}}}}
</style></head><body>
<div class="card">
  <div class="brand"><div class="drop"></div>OilMitra</div>
  <div class="muted">Pickup receipt \u00b7 {e(when)}</div>
  <div class="amount">\u20b9{float(p.amount or 0):,.0f}</div>
  <div class="litres">{float(p.actual_liters or 0):g} litres \u00b7 {e(listing.title)}</div>
  <table>{row_html}</table>
  <div class="impact"><b>{co2:g} kg CO\u2082e avoided</b>{bio:g} L of biodiesel can be made from this load.</div>
  <div class="foot">Receipt {e(token)} \u00b7 Generated by OilMitra<br>
  This receipt records a pickup between the two parties above.</div>
</div></body></html>""")


def _not_found() -> str:
    return "<html><body style='font-family:system-ui;padding:40px'><h2>Receipt not found</h2></body></html>"


@rates_router.put("/{oil_type}", response_model=RateOut)
def set_rate(oil_type: str, body: RateIn, db: Session = Depends(get_db), _=Depends(admin_user)):
    rate = db.scalar(select(Rate).where(Rate.oil_type == oil_type))
    if rate is None:
        raise HTTPException(404, "Unknown oil type")
    rate.price_per_liter = body.price_per_liter
    rate.updated_at = datetime.now()
    db.commit()
    return rate_out(rate)
