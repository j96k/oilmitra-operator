"""End-to-end smoke test against a running server. Standard library only.

    python tests/smoke_test.py [base_url]

The test is safe to run repeatedly: it reuses the demo operator account and the
``supplier_smoke`` account, and compares dashboard totals before/after each run
instead of assuming an empty database.
"""

import json
import sys
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8010").rstrip("/")
FAILS = []


def call(method, path, token=None, body=None, form=None):
    headers = {}
    data = None
    if form is not None:
        boundary = "----OilMitra" + uuid.uuid4().hex
        parts = []
        for key, value in form.items():
            parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{key}\"\r\n\r\n{value}\r\n")
        parts.append(f"--{boundary}--\r\n")
        data = "".join(parts).encode()
        headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
    elif body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as res:
            raw = res.read().decode()
            ctype = res.headers.get("Content-Type", "")
            return res.status, (json.loads(raw) if "json" in ctype else raw)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + (f"  {detail}" if not ok else ""))
    if not ok:
        FAILS.append(name)


def login_or_register(username, password, name, org_type, city):
    """Register on a fresh database, otherwise log in to the existing account."""
    status, out = call("POST", "/auth/register", body={
        "username": username, "password": password, "name": name, "role": "supplier",
        "org_type": org_type, "phone": "9876543210", "city": city,
    })
    if status != 200:
        status, out = call("POST", "/auth/login", body={"username": username, "password": password})
    assert status == 200, out
    return out


def new_listing(token, title):
    now = datetime.now()
    return call("POST", "/listings", token=token, form={
        "title": title,
        "oil_type": "sunflower",
        "approx_liters": "40",
        "rate_per_liter": "52",
        "address": "Ring Road, near Saffron Hotel, Surat",
        "area": "Ring Road",
        "city": "Surat",
        "pincode": "395002",
        "lat": "21.1702",
        "lng": "72.8311",
        "phone": "9876543210",
        "available_from": now.strftime("%Y-%m-%dT%H:%M:%S"),
        "available_to": (now + timedelta(days=2)).strftime("%Y-%m-%dT%H:%M:%S"),
        "notes": "Stored in sealed cans behind the kitchen.",
    })


status, health = call("GET", "/")
check("health", status == 200 and health.get("app") == "OilMitra", str(health))

# The demo username is listed in ADMIN_USERNAMES, so logging in repairs/promotes
# its role to admin. This is the account the separate /admin/ app uses.
admin = login_or_register("demo", "123456", "OilMitra Operator", "other", "Surat")
a_token = admin["access_token"]
check("admin account", admin["user"]["is_admin"] is True and admin["user"]["role"] == "admin", str(admin["user"]))

supplier = login_or_register("supplier_smoke", "123456", "Smoke Test Kitchen", "restaurant", "Surat")
s_token = supplier["access_token"]
check("supplier account", supplier["user"]["role"] == "supplier" and supplier["user"]["is_admin"] is False,
      str(supplier["user"]))

# The old collector role must be rejected at registration.
status, rejected = call("POST", "/auth/register", body={
    "username": "collector_" + uuid.uuid4().hex[:8], "password": "123456", "name": "Old Collector",
    "role": "collector", "org_type": "other", "phone": "9876543210", "city": "Surat",
})
check("collector role retired", status == 422, str(rejected)[:200])

status, dashboard_before = call("GET", "/dashboard", token=s_token)
check("supplier dashboard before", status == 200, str(dashboard_before)[:200])
liters_before = float(dashboard_before.get("impact", {}).get("liters", 0))
pickups_before = int(dashboard_before.get("impact", {}).get("pickups", 0))

status, admin_before = call("GET", "/dashboard", token=a_token)
check("admin dashboard before", status == 200 and admin_before.get("role") == "admin", str(admin_before)[:200])
money_before = float(admin_before.get("money_total", 0))

status, listing = new_listing(s_token, "Used sunflower oil - 40L")
check("create listing", status == 200 and listing.get("status") == "open", str(listing)[:300])
listing_id = listing.get("id")

status, nearby = call("GET", "/listings?lat=21.17&lng=72.83", token=s_token)
check("supplier radar excludes own load", status == 200 and all(x["id"] != listing_id for x in nearby), str(nearby)[:300])

status, nearby = call("GET", "/listings?lat=21.17&lng=72.83", token=a_token)
check("admin sees nearby load", status == 200 and any(x["id"] == listing_id for x in nearby), str(nearby)[:300])
check("distance computed", status == 200 and nearby[0].get("distance_km") is not None)

status, denied = call("POST", f"/listings/{listing_id}/claim", token=s_token, body={})
check("supplier cannot claim", status == 403, str(denied)[:200])

status, pickup = call("POST", f"/listings/{listing_id}/claim", token=a_token, body={})
check("admin claim", status == 200 and pickup.get("status") == "scheduled", str(pickup)[:300])

status, again = call("POST", f"/listings/{listing_id}/claim", token=a_token, body={})
check("double claim blocked", status == 400, str(again)[:200])

status, done = call("POST", f"/listings/{listing_id}/collect", token=a_token,
                    body={"actual_liters": 37.5, "rate_per_liter": 52, "notes": "3 cans"})
check("admin collect", status == 200 and done.get("amount") == 1950.0, str(done)[:300])
token_receipt = done.get("receipt_token")

status, dash_s = call("GET", "/dashboard", token=s_token)
check("supplier dashboard grew", status == 200
      and float(dash_s["impact"]["liters"]) >= liters_before + 37.5 - 0.01
      and int(dash_s["impact"]["pickups"]) >= pickups_before + 1, str(dash_s)[:300])

status, dash_a = call("GET", "/dashboard", token=a_token)
check("admin dashboard money grew", status == 200
      and float(dash_a["money_total"]) >= money_before + 1950.0 - 0.01, str(dash_a)[:300])

status, impact = call("GET", "/impact", token=s_token)
check("impact", status == 200 and impact["co2_kg"] > 0, str(impact))

status, board = call("GET", "/leaderboard")
check("leaderboard", status == 200 and len(board) >= 1, str(board)[:300])

status, page = call("GET", f"/r/{token_receipt}")
check("receipt HTML", status == 200 and "CO" in page and "1,950" in page, str(page)[:300])

status, all_loads = call("GET", "/listings?scope=all", token=a_token)
check("admin sees every status", status == 200 and any(x["id"] == listing_id for x in all_loads),
      str(all_loads)[:300])

# Admin can cancel and delete any supplier's load, not just their own.
status, second = new_listing(s_token, "Used sunflower oil - admin cancel test")
check("second listing", status == 200, str(second)[:300])
second_id = second.get("id")
status, cancelled = call("POST", f"/listings/{second_id}/cancel", token=a_token)
check("admin cancels any listing", status == 200 and cancelled.get("status") == "cancelled", str(cancelled)[:300])
status, _ = call("DELETE", f"/listings/{second_id}", token=a_token)
check("admin deletes cancelled load", status == 200)

status, third = new_listing(s_token, "Used sunflower oil - admin delete test")
third_id = third.get("id")
status, _ = call("DELETE", f"/listings/{third_id}", token=a_token)
check("admin deletes open load", status == 200)
status, gone = call("GET", f"/listings/{third_id}", token=a_token)
check("deleted load is gone", status == 404, str(gone)[:200])

status, rates = call("GET", "/rates")
check("rate board", status == 200 and len(rates) == 6, str(rates)[:200])

status, geo = call("GET", "/geo/search?q=Surat")
check("geocode", status == 200 and len(geo) > 0, str(geo)[:200])

status, me = call("GET", "/auth/me", token=a_token)
check("admin me", status == 200 and me["role"] == "admin" and me["is_admin"] is True, str(me))

status, page_app = call("GET", "/app/")
check("supplier web app", status == 200 and "<base href=\"/app/\">" in page_app, str(page_app)[:120])
status, page_admin = call("GET", "/admin/")
check("operator web app", status == 200 and "<base href=\"/admin/\">" in page_admin, str(page_admin)[:120])

print()
print(f"{len(FAILS)} failure(s)" if FAILS else "All checks passed")
sys.exit(1 if FAILS else 0)
