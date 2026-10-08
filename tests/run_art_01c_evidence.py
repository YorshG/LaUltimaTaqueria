#!/usr/bin/env python3
"""Canonical frozen fixtures on immutable B/uat exports; interleaved desktop runs."""
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile
import run_art_01_evidence as evidence

ROOT = evidence.ROOT
OUT = ROOT / 'docs/art-01c/evidence'
evidence.OUT = OUT
REFS = {'uat': 'd46cc8cdebb363a7791da8417d78870da3e676d1',
        'art01b': '5e4bc11dd2c68a2b7563437e8cdeb98d39a97dc3'}


def run(project, label, *args):
    evidence.run(project, label, '--resolution', '540x960', *args)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    performance_only = '--performance-only' in sys.argv
    captures_only = '--captures-only' in sys.argv
    with ExitStack() as stack:
        projects = {'art01c': ROOT}
        for prefix, sha in REFS.items():
            directory = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix='art01c-' + prefix)))
            archive = directory / 'source.zip'
            with archive.open('wb') as stream:
                subprocess.run(['git', 'archive', '--format=zip', sha], cwd=ROOT, stdout=stream, check=True)
            with zipfile.ZipFile(archive) as zipped:
                zipped.extractall(directory)
            for name in ['art_01c_fixture.gd', 'art_01c_capture.gd', 'art_01c_performance.gd']:
                shutil.copyfile(ROOT / 'tests' / name, directory / 'tests' / name)
            projects[prefix] = directory
            run(directory, prefix + '-import', '--headless', '--editor', '--quit')
        run(ROOT, 'import', '--headless', '--editor', '--quit')
        if not performance_only:
            for prefix in ['art01b', 'art01c']:
                for height in [1620, 1920, 2400]:
                    for mode in ['regular', 'fractional', 'crowded', 'unselected', 'bounds']:
                        label = f'{prefix}-{mode}-{height}'
                        run(projects[prefix], label, '--script', 'res://tests/art_01c_capture.gd', '--', str(OUT / (label + '.png')), str(height), mode)
            run(ROOT, 'pixels', '--script', 'res://tests/art_01c_pixels.gd', '--', str(OUT))
            run(ROOT, 'comparisons', '--script', 'res://tests/art_01c_comparison.gd', '--', str(OUT))
        if not captures_only:
            # All runs sequential, references interleaved each round; no concurrent
            # tests/captures. Keep every run including outliers.
            for iteration in range(1, 6):
                for prefix in ['uat', 'art01b', 'art01c']:
                    run(projects[prefix], f'perf-{prefix}-{iteration}', '--script', 'res://tests/art_01c_performance.gd')
            report = {}
            for prefix in ['uat', 'art01b', 'art01c']:
                report[prefix] = [json.loads(line.removeprefix('ART_PERFORMANCE '))
                                  for log in sorted(OUT.glob(f'perf-{prefix}-[0-9].log'))
                                  for line in log.read_text().splitlines()
                                  if line.startswith('ART_PERFORMANCE ')]
            (OUT / 'performance.json').write_text(json.dumps(report, indent=2) + '\n')
    manifest = {'baseline_refs': REFS, 'fixture': 'tests/art_01c_fixture.gd', 'board_seed': 20260920,
                'monsters_sha256': hashlib.sha256((ROOT / 'data/content/monsters.json').read_bytes()).hexdigest(),
                'fixture_sha256': hashlib.sha256((ROOT / 'tests/art_01c_fixture.gd').read_bytes()).hexdigest(),
                'canonical_monsters': json.loads((ROOT / 'data/content/monsters.json').read_text()),
                'not_played_sessions': True, 'physical_testing': False}
    (OUT / 'fixture-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('ART-01C EVIDENCE PASS', flush=True)


if __name__ == '__main__':
    main()
