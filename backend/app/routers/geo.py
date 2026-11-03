"""Address search + reverse geocoding through OpenStreetMap (free, no API key).

The app uses this to turn a typed address into map coordinates, and a map tap
back into a readable address. Requests are made server-side so the phone never
has to deal with CORS, and we send a proper User-Agent as OSM asks.
"""

import json
import urllib.parse
import urllib.request

from fastapi import APIRouter, HTTPException, Query

router = APIRouter(prefix="/geo", tags=["Address & map"])

_UA = "OilMitra/1.0 (used cooking oil pickup app)"
_TIMEOUT = 12


def _get(url: str) -> list | dict:
    req = urllib.request.Request(url, headers={"User-Agent": _UA, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=_TIMEOUT) as res:
            return json.loads(res.read().decode("utf-8"))
    except Exception:
        raise HTTPException(503, "Address search is not reachable right now — tap the map instead")


def _label(item: dict) -> str:
    return (item.get("display_name") or "").split(", India")[0][:180]


@router.get("/search")
def search(q: str = Query(min_length=2, max_length=200), limit: int = 6, country: str = "in"):
    params = {"format": "json", "q": q, "limit": max(1, min(limit, 10)), "addressdetails": "0"}
    if country:
        params["countrycodes"] = country
    data = _get("https://nominatim.openstreetmap.org/search?" + urllib.parse.urlencode(params))
    if not isinstance(data, list):
        return []
    return [
        {"label": _label(x), "lat": float(x["lat"]), "lng": float(x["lon"])}
        for x in data
        if x.get("lat") and x.get("lon")
    ]


@router.get("/reverse")
def reverse(lat: float, lng: float):
    params = {"format": "json", "lat": lat, "lon": lng, "zoom": 18}
    data = _get("https://nominatim.openstreetmap.org/reverse?" + urllib.parse.urlencode(params))
    if not isinstance(data, dict) or "error" in data:
        raise HTTPException(404, "No address found at those coordinates")
    addr = data.get("address", {})
    city = addr.get("city") or addr.get("town") or addr.get("village") or addr.get("state_district")
    area = addr.get("suburb") or addr.get("neighbourhood") or addr.get("road")
    return {
        "label": _label(data),
        "house": addr.get("house_number"),
        "road": addr.get("road"),
        "area": area,
        "city": city,
        "state": addr.get("state"),
        "pincode": addr.get("postcode"),
    }
