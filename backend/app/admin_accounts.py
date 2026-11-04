"""Operator (admin) accounts.

Admins live in their own ``admins`` table and are created by hand — see
``backend/scripts/create_admin.py``. There is no self-service admin sign-up.

Every admin also keeps a mirror row in ``users`` because listings and pickups
reference ``users.id`` (a pickup stores ``collector_id``). The ``admins`` table
is the source of truth for the username and password; the mirror row is created
and updated automatically.
"""

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import Admin, User
from .security import hash_password

DEFAULT_ADMIN_NAME = "OilMitra operator"


def normalise(username: str) -> str:
    return (username or "").strip().lower()


def find_admin(db: Session, username: str) -> Admin | None:
    name = normalise(username)
    if not name:
        return None
    return db.scalar(select(Admin).where(Admin.username == name))


def admin_username_exists(db: Session, username: str) -> bool:
    return find_admin(db, username) is not None


def sync_admin_user(db: Session, admin: Admin) -> User:
    """Create or refresh the ``users`` row that links an admin to pickups."""
    user = db.scalar(select(User).where(User.username == admin.username))
    if user is None:
        user = User(
            username=admin.username,
            password_hash=admin.password_hash,
            name=admin.name or DEFAULT_ADMIN_NAME,
            role="admin",
            org_type="other",
        )
        db.add(user)
    else:
        # The admins table wins: same password, and always the admin role.
        user.role = "admin"
        user.password_hash = admin.password_hash
        if admin.name:
            user.name = admin.name
    db.commit()
    db.refresh(user)
    return user


def sync_all_admins(db: Session) -> int:
    """Make sure every admin row has a working ``users`` mirror row."""
    admins = db.scalars(select(Admin)).all()
    for admin in admins:
        sync_admin_user(db, admin)
    return len(admins)


def create_admin(
    db: Session,
    username: str,
    password: str,
    name: str | None = None,
    replace: bool = False,
) -> Admin:
    """Insert an admin row (or reset the password when ``replace`` is true)."""
    username = normalise(username)
    if not username:
        raise ValueError("A username is required")
    if len(password) < 6:
        raise ValueError("The password must be at least 6 characters")
    admin = find_admin(db, username)
    if admin is not None and not replace:
        raise ValueError(f"The admin '{username}' already exists (use --replace to reset the password)")
    if admin is None:
        admin = Admin(
            username=username,
            password_hash=hash_password(password),
            name=(name or DEFAULT_ADMIN_NAME),
        )
        db.add(admin)
    else:
        admin.password_hash = hash_password(password)
        if name:
            admin.name = name
    db.commit()
    db.refresh(admin)
    sync_admin_user(db, admin)
    return admin
