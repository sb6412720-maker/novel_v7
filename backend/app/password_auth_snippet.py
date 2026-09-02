# === Paste helpers near other auth helpers in backend/app/main.py ===
import hashlib
import secrets

# def _ensure_password_hash_column() -> None:
#     """Add password_hash to app_users if missing (MySQL + SQLite)."""
#     try:
#         if USE_SQLITE:
#             execute_write("ALTER TABLE app_users ADD COLUMN password_hash TEXT", ())
#         else:
#             execute_write("ALTER TABLE app_users ADD COLUMN password_hash VARCHAR(255) NULL", ())
#     except Exception:
#         pass


def _hash_password(password: str, salt: str | None = None) -> str:
    salt = salt or secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), salt.encode("utf-8"), 120_000
    ).hex()
    return f"{salt}${digest}"


def _verify_password(password: str, stored: str | None) -> bool:
    if not stored or "$" not in stored:
        return False
    salt, digest = stored.split("$", 1)
    check = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), salt.encode("utf-8"), 120_000
    ).hex()
    return secrets.compare_digest(check, digest)


# === Replace class EmailAuthRequest with: ===
# class EmailAuthRequest(BaseModel):
#     email: str
#     display_name: str = ""
#     password: str = ""
#     username: str = ""


# === Replace authenticate_email body with the logic in AUTH_EMAIL_HANDLER.py ===
