#!/usr/bin/env python3
"""Full regression inventory; keep historical evidence immutable."""
import run_art_01_regression as regression
regression.OUT = regression.ROOT / "docs/art-01d/evidence"
regression.SCRIPTS = ["art_01d_audit_test", "ui_mobile_layout_test", "art_01c_audit_test", "art_01b_layout_test", *regression.SCRIPTS]
if __name__ == "__main__":
    regression.main()
