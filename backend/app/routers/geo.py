"""Address search + reverse geocoding.

Google Places and Google Geocoding are used when GOOGLE_MAPS_API_KEY is set.
Without a key — or whenever Google fails — the free OpenStreetMap Nominatim
service is used instead.

Every request is made server-side, so the Google key is never compiled into the
Android APK where anyone could extract it.
"""

import json
import logging
import urllib.error
import urllib.parse
import urllib.request

from fastapi import APIRouter, HTTPException, Query

from ..config import settings

router = APIRouter(prefix="/geo", tags=["Address & map"])
log = logging.getLogger("oilmitra.geo")

_UA = "OilMitra/1.0 (used cooking oil pickup app)"
_TIMEOUT = 12


def _request_json(url: str, *, data: bytes | None = None, headers: dict[str, str] | None = None):
    req = urllib.request.Request(url, data=data, headers={"User-Agent": _UA, **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=_TIMEOUT) as res:
            return json.loads(res.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "ignore")[:300]
        raise RuntimeError(f"HTTP {exc.code}: {detail}") from exc
    except Exception as exc:  # timeout, DNS, bad JSON
        raise RuntimeError(str(exc)) from exc


def _google_key() -> str:
    return settings.google_maps_api_key.strip()


# ---------------------------------------------------------------- Google Places

def _google_search(q: str, limit: int, country: str) -> list[dict] | None:
    """Search with Google Places (New). Returns None when Google can't answer."""
    key = _google_key()
    if not key:
        return None
    payload = {
        "textQuery": q,
        "languageCode": "en",
        "maxResultCount": max(1, min(limit, 10)),
    }
    if country:
        payload["regionCode"] = country.upper()
    try:
        data = _request_json(
            "https://places.googleapis.com/v1/places:searchText",
            data=json.dumps(payload).encode(),
            headers={
                "Content-Type": "application/json",
                "X-Goog-Api-Key": key,
                "X-Goog-FieldMask": "places.displayName,places.formattedAddress,places.location",
            },
        )
    except RuntimeError as exc:
        log.warning("Google Places search failed (%s) - falling back to OpenStreetMap", exc)
        return None

    results: list[dict] = []
    for place in data.get("places") or []:
        loc = place.get("location") or {}
        lat, lng = loc.get("latitude"), loc.get("longitude")
        if lat is None or lng is None:
            continue
        name = ((place.get("displayName") or {}).get("text") or "").strip()
        address = (place.get("formattedAddress") or "").strip()
        label = address or name
        if name and address and not address.lower().startswith(name.lower()):
            label = f"{name}, {address}"
        results.append({"label": label[:180], "lat": float(lat), "lng": float(lng)})
    return results


def _component(components: list[dict], *types: str) -> str | None:
    for item in components:
        if any(t in (item.get("types") or []) for t in types):
            return item.get("long_name")
    return None


def _google_reverse(lat: float, lng: float) -> dict | None:
    """Turn coordinates into an address with Google. None when unavailable."""
    key = _google_key()
    if not key:
        return None
    params = {"latlng": f"{lat},{lng}", "key": key, "language": "en", "region": "in"}
    try:
        data = _request_json(
            "https://maps.googleapis.com/maps/api/geocode/json?" + urllib.parse.urlencode(params)
        )
    except RuntimeError as exc:
        log.warning("Google reverse geocoding failed (%s) - falling back to OpenStreetMap", exc)
        return None
    status = data.get("status")
    if status != "OK" or not data.get("results"):
        log.warning("Google reverse geocoding returned %s - falling back to OpenStreetMap", status)
        return None
    first = data["results"][0]
    comps = first.get("address_components") or []
    return {
        "label": (first.get("formatted_address") or "")[:180],
        "house": _component(comps, "street_number"),
        "road": _component(comps, "route"),
        "area": _component(comps, "sublocality_level_2", "sublocality_level_1", "sublocality", "neighborhood"),
        "city": _component(comps, "locality", "postal_town", "administrative_area_level_2"),
        "state": _component(comps, "administrative_area_level_1"),
        "pincode": _component(comps, "postal_code"),
    }


# ------------------------------------------------------------- OpenStreetMap

def _osm(url: str) -> list | dict:
    try:
        return _request_json(url, headers={"Accept": "application/json"})
    except RuntimeError:
        raise HTTPException(503, "Address search is not reachable right now — tap the map instead")


def _label(item: dict) -> str:
    return (item.get("display_name") or "").split(", India")[0][:180]


# ------------------------------------------------------------------- Routes

@router.get("/search")
def search(q: str = Query(min_length=2, max_length=200), limit: int = 6, country: str = "in"):
    places = _google_search(q, limit, country)
    if places is not None:
        return places

    params = {"format": "json", "q": q, "limit": max(1, min(limit, 10)), "addressdetails": "0"}
    if country:
        params["countrycodes"] = country
    data = _osm("https://nominatim.openstreetmap.org/search?" + urllib.parse.urlencode(params))
    if not isinstance(data, list):
        return []
    return [
        {"label": _label(x), "lat": float(x["lat"]), "lng": float(x["lon"])}
        for x in data
        if x.get("lat") and x.get("lon")
    ]


@router.get("/reverse")
def reverse(lat: float, lng: float):
    google = _google_reverse(lat, lng)
    if google is not None:
        return google

    params = {"format": "json", "lat": lat, "lon": lng, "zoom": 18}
    data = _osm("https://nominatim.openstreetmap.org/reverse?" + urllib.parse.urlencode(params))
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
