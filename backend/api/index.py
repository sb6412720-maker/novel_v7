from __future__ import annotations

# Ensure backend root is importable when Vercel runs this file as the entry.
import sys
from pathlib import Path

_BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(_BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(_BACKEND_ROOT))

from app.main import app  # noqa: E402,F401

# Vercel looks for `app` in this module.
__all__ = ["app"]
