#!/usr/bin/env python3
"""Full regression inventory, preserving ART-01/01B historical evidence."""
import run_art_01_regression as regression

regression.OUT = regression.ROOT / "docs/art-01c/evidence"
regression.SCRIPTS = ["art_01c_audit_test", "art_01b_layout_test", *regression.SCRIPTS]

if __name__ == "__main__":
    regression.main()
