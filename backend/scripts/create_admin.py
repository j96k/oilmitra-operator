#!/usr/bin/env python
"""Create an OilMitra operator account — the login used at /admin/.

Admins are never created from the apps. Run this script once per operator.

Run it from F:\\OilMitra\\backend:

    .venv\\Scripts\\python.exe scripts\\create_admin.py nilesh "MyStrongPass1"
    .venv\\Scripts\\python.exe scripts\\create_admin.py nilesh "NewPass1" --name "Nilesh Borana" --replace
    .venv\\Scripts\\python.exe scripts\\create_admin.py --list
    .venv\\Scripts\\python.exe scripts\\create_admin.py --hash "MyStrongPass1"

To write to the online Neon database instead of the local file, pass its
connection string (copy it from the Neon dashboard):

    .venv\\Scripts\\python.exe scripts\\create_admin.py nilesh "MyStrongPass1" ^
        --database-url "postgresql://user:pass@host/db?sslmode=require"

The same admin can sign in to the operator console (/admin/) and to the
supplier app (/app/).
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))


def _print_admins(rows) -> None:
    if not rows:
        print("No operators yet. Create one with:")
        print('  .venv\\Scripts\\python.exe scripts\\create_admin.py <username> "<password>"')
        return
    print(f"{'USERNAME':<24} {'NAME':<28} CREATED")
    print("-" * 68)
    for admin in rows:
        created = admin.created_at.strftime("%Y-%m-%d %H:%M") if admin.created_at else "-"
        print(f"{admin.username:<24} {(admin.name or '-')[:28]:<28} {created}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Create or reset an OilMitra operator login.")
    parser.add_argument("username", nargs="?", help="operator username (letters, digits, _ and .)")
    parser.add_argument("password", nargs="?", help="password, at least 6 characters")
    parser.add_argument("--name", help="display name, e.g. \"Nilesh Borana\"")
    parser.add_argument("--replace", action="store_true", help="reset the password of an existing operator")
    parser.add_argument("--list", action="store_true", help="show every operator")
    parser.add_argument("--hash", metavar="PASSWORD", help="only print a bcrypt hash (for manual SQL)")
    parser.add_argument("--database-url", help="DATABASE_URL to use (e.g. your Neon string)")
    args = parser.parse_args()

    # No database needed just to print a hash.
    if args.hash:
        import bcrypt

        print(bcrypt.hashpw(args.hash.encode(), bcrypt.gensalt()).decode())
        return 0

    if args.database_url:
        os.environ["DATABASE_URL"] = args.database_url
        os.environ["DB_TYPE"] = "postgres"

    from sqlalchemy import select

    from app.admin_accounts import create_admin
    from app.config import settings
    from app.database import SessionLocal
    from app.models import Admin

    target = f"Neon/PostgreSQL: {settings.database_url.split('@')[-1]}" if settings.is_postgres else "local SQLite file"
    print(f"Database: {target}")

    with SessionLocal() as db:
        if args.list:
            _print_admins(db.scalars(select(Admin).order_by(Admin.username)).all())
            return 0

        if not args.username or not args.password:
            parser.error("username and password are required (or use --list)")

        try:
            admin = create_admin(
                db,
                username=args.username,
                password=args.password,
                name=args.name,
                replace=args.replace,
            )
        except ValueError as exc:
            print(f"ERROR: {exc}")
            return 1

        action = "updated" if args.replace else "created"
        print(f"Operator {action}: {admin.username}  ({admin.name})")
        print("Sign in at /admin/ with that username and password.")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
