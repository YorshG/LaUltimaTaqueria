#!/usr/bin/env python3
"""Canonical frozen fixtures on immutable C/uat exports; interleaved desktop runs."""
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
OUT = ROOT / 'docs/art-01d/evidence'
evidence.OUT = OUT
REFS = {'uat': 'd46cc8cdebb363a7791da8417d78870da3e676d1',
        'art01c': 'c283b337dd5ccd7355ad554a58743ff972151d3b'}


def run(project, label, *args):
    evidence.run(project, label, '--resolution', '540x960', *args)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    performance_only = '--performance-only' in sys.argv
    captures_only = '--captures-only' in sys.argv
    with ExitStack() as stack:
        projects = {'art01d': ROOT}
        for prefix, sha in REFS.items():
            directory = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix='art01d-' + prefix)))
            archive = directory / 'source.zip'
            with archive.open('wb') as stream:
                subprocess.run(['git', 'archive', '--format=zip', sha], cwd=ROOT, stdout=stream, check=True)
            with zipfile.ZipFile(archive) as zipped:
                zipped.extractall(directory)
            for name in ['art_01c_fixture.gd', 'art_01d_fixture.gd', 'art_01d_capture.gd', 'art_01c_performance.gd', 'art_01d_performance.gd']:
                shutil.copyfile(ROOT / 'tests' / name, directory / 'tests' / name)
            projects[prefix] = directory
            run(directory, prefix + '-import', '--headless', '--editor', '--quit')
        run(ROOT, 'import', '--headless', '--editor', '--quit')
        if not performance_only:
            for prefix in ['art01c', 'art01d']:
                for height in [1620, 1920, 2400]:
                    for mode in ['regular', 'fractional', 'crowded', 'unselected', 'bounds', 'turns', 'chain-2', 'chain-3', 'chain-4', 'chain-5', 'subunit']:
                        label = f'{prefix}-{mode}-{height}'
                        run(projects[prefix], label, '--script', 'res://tests/art_01d_capture.gd', '--', str(OUT / (label + '.png')), str(height), mode)
            run(ROOT, 'pixels', '--script', 'res://tests/art_01d_single_pixels.gd', '--', str(OUT))
            run(ROOT, 'chain-pixels', '--script', 'res://tests/art_01d_pixels.gd')
            run(ROOT, 'grayscale', '--script', 'res://tests/art_01d_grayscale.gd', '--', str(OUT))
            run(ROOT, 'comparisons', '--script', 'res://tests/art_01d_comparison.gd', '--', str(OUT))
        if not captures_only:
            # All runs sequential, references interleaved each round; no concurrent
            # tests/captures. Keep every run including outliers.
            for iteration in range(1, 6):
                for prefix in ['uat', 'art01c', 'art01d']:
                    run(projects[prefix], f'perf-{prefix}-{iteration}', '--script', 'res://tests/art_01c_performance.gd')
                    run(projects[prefix], f'selected-perf-{prefix}-{iteration}', '--script', 'res://tests/art_01d_performance.gd')
            report = {}
            for prefix in ['uat', 'art01c', 'art01d']:
                report[prefix] = [json.loads(line.removeprefix('ART_PERFORMANCE '))
                                  for log in sorted(OUT.glob(f'perf-{prefix}-[0-9].log'))
                                  for line in log.read_text().splitlines()
                                  if line.startswith('ART_PERFORMANCE ')]
            for prefix in ['uat', 'art01c', 'art01d']:
                report[prefix + '-selected'] = [json.loads(line.removeprefix('ART_PERFORMANCE ')) for log in sorted(OUT.glob(f'selected-perf-{prefix}-[0-9].log')) for line in log.read_text().splitlines() if line.startswith('ART_PERFORMANCE ')]
            (OUT / 'performance.json').write_text(json.dumps(report, indent=2) + '\n')
    manifest = {'baseline_refs': REFS, 'fixture': 'tests/art_01d_fixture.gd', 'capture_sha256': hashlib.sha256((ROOT / 'tests/art_01d_capture.gd').read_bytes()).hexdigest(), 'board_seed': 20260920,
                'monsters_sha256': hashlib.sha256((ROOT / 'data/content/monsters.json').read_bytes()).hexdigest(),
                'fixture_sha256': hashlib.sha256((ROOT / 'tests/art_01d_fixture.gd').read_bytes()).hexdigest(),
                'canonical_monsters': json.loads((ROOT / 'data/content/monsters.json').read_text()),
                'not_played_sessions': True, 'physical_testing': False}
    (OUT / 'fixture-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('ART-01D EVIDENCE PASS', flush=True)


if __name__ == '__main__':
    main()
