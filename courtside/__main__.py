"""Entry point so the package can run as ``python -m courtside``."""
from .cli import main

if __name__ == "__main__":
    raise SystemExit(main())
