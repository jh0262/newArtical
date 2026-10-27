"""Use the existing workspace Python 3.12 dependency directory read-only."""
import sys
from pathlib import Path
WORKSPACE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(WORKSPACE / '.v3deps'))
