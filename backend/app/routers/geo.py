"""Address search + reverse geocoding.

Google **Geocoding** is used when GOOGLE_MAPS_API_KEY is set. Without a key —
or whenever Google fails — the free OpenStreetMap Nominatim service is used
instead.

Only the Geocoding API needs to be enabled for the key:
    https://maps.googleapis.com/maps/api/geocode/json

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
_GEOCODE_URL = "https://maps.googleapis.com/maps/api/geocode/json"


def _request_json(url: str, *, headers: dict[str, str] | None = None):
    req = urllib.request.Request(url, headers={"User-Agent": _UA, **(headers or {})})
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


# ------------------------------------------------------------- Google Geocoding

def _google_geocode(params: dict[str, str]) -> dict | None:
    """Call the Geocoding API.

    Returns the Google payload for OK / ZERO_RESULTS, or None when the key is
    missing or Google rejects the request (so the caller can use OpenStreetMap).
    """
    key = _google_key()
    if not key:
        return None
    query = {**params, "key": key, "language": "en"}
    try:
        data = _request_json(_GEOCODE_URL + "?" + urllib.parse.urlencode(query))
    except RuntimeError as exc:
        log.warning("Google Geocoding request failed (%s) - falling back to OpenStreetMap", exc)
        return None

    status = (data.get("status") or "").upper()
    if status in ("OK", "ZERO_RESULTS"):
        return data
    # REQUEST_DENIED, OVER_QUERY_LIMIT, INVALID_REQUEST, UNKNOWN_ERROR...
    error = data.get("error_message") or status or "no status"
    log.warning("Google Geocoding returned %s - falling back to OpenStreetMap", error)
    return None


def _google_search(q: str, limit: int, country: str) -> list[dict] | None:
    """Address -> coordinates with the Geocoding API. None = use OpenStreetMap."""
    params = {"address": q}
    if country:
        params["components"] = f"country:{country.upper()}"
    data = _google_geocode(params)
    if data is None:
        return None

    results: list[dict] = []
    for item in (data.get("results") or [])[: max(1, min(limit, 10))]:
        loc = (item.get("geometry") or {}).get("location") or {}
        lat, lng = loc.get("lat"), loc.get("lng")
        label = (item.get("formatted_address") or "").strip()
        if lat is None or lng is None or not label:
            continue
        results.append({"label": label[:180], "lat": float(lat), "lng": float(lng)})
    return results


def _component(components: list[dict], *types: str) -> str | None:
    for item in components:
        if any(t in (item.get("types") or []) for t in types):
            return item.get("long_name")
    return None


def _google_reverse(lat: float, lng: float) -> dict | None:
    """Coordinates -> address with the Geocoding API. None = use OpenStreetMap."""
    data = _google_geocode({"latlng": f"{lat},{lng}"})
    if data is None:
        return None

    results = data.get("results") or []
    if not results:
        log.warning("Google Geocoding found no address at %s,%s - falling back to OpenStreetMap", lat, lng)
        return None

    first = results[0]
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

@router.get("/status")
def status():
    """Is a Google key configured? Never returns the key itself.

    Use this to confirm the Render environment variable reached the server:
        GET /geo/status  ->  {"google_configured": true, "provider": "google"}
    """
    configured = bool(_google_key())
    return {"provider": "google" if configured else "openstreetmap", "google_configured": configured}


@router.get("/config")
def map_config():
    """Public browser map config for the Flutter web apps.

    `web/index.html` fetches this before starting Flutter and loads the Google
    Maps JavaScript API with the key. This is a **browser key**, so it is meant
    to be visible: restrict it in Google Cloud to the app's HTTP referrers
    (and to Maps JavaScript API + Geocoding API). The server-side key is never
    written into the committed web bundles.
    """
    return {"provider": "google", "key": settings.google_maps_api_key or ""}


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
