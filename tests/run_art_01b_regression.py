#!/usr/bin/env python3
"""Run historical ART-01 regressions without replacing their evidence."""
import run_art_01_regression as regression

regression.OUT = regression.ROOT / "docs/art-01b/evidence"
regression.SCRIPTS = ["art_01b_layout_test", *regression.SCRIPTS]

if __name__ == "__main__":
    regression.main()
