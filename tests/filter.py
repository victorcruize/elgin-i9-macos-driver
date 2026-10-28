"""Offline protocol tests. Requires Python 3 only for development tests."""
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    filt, fixture = pathlib.Path(tmp) / 'filter', pathlib.Path(tmp) / 'fixture'
    for src, out in [(ROOT / 'rastertoelgini9.c', filt), (ROOT / 'tests/raster-fixture.c', fixture)]:
        subprocess.run(['clang', '-O2', '-Wall', '-Wextra', str(src), '-lcups', '-lm', '-o', str(out)], check=True)
    raster = subprocess.check_output([str(fixture), '2'])

    def run(options='', data=raster):
        result = subprocess.run([str(filt), '1', 'test', 'fixture', '1',
                                 'ElginDelay=0 ' + options], input=data, capture_output=True, check=True)
        d, i, events = result.stdout, 2, []
        assert d[:2] == b'\x1b@'
        while i < len(d):
            if d[i:i+4] == b'\x1dv0\0':
                w = int.from_bytes(d[i+4:i+6], 'little')
                n = int.from_bytes(d[i+6:i+8], 'little')
                payload = d[i+8:i+8+w*n]
                assert w == 72 and len(payload) == w*n
                events.append(('raster', n, payload))
                i += 8 + w*n
            elif d[i:i+3] in (b'\x1dVB', b'\x1dVA'):
                assert d[i+3] == 0
                events.append(('cut', d[i+2]))
                i += 4
            elif d[i:i+3] == b'\x1bd\x04':
                events.append(('feed-lines', 4))
                i += 3
            else:
                raise AssertionError((i, d[i:i+8]))
        return events

    def rows(e): return sum(x[1] for x in e if x[0] == 'raster')
    def cuts(e): return sum(x[0] == 'cut' for x in e)
    default = run()
    assert cuts(default) == 2
    job = run('ElginFinishScope=Job')
    assert cuts(job) == 1 and job[-1][0] == 'cut'
    assert rows(default) == rows(job)
    no_cut = run('ElginCut=None ElginFinishScope=Job')
    assert cuts(no_cut) == 0 and sum(x[0] == 'feed-lines' for x in no_cut) == 1
    full = run('ElginCut=Full')
    assert [x[1] for x in full if x[0] == 'cut'] == [65, 65]
    for mm in (0, 5, 10, 15, 20, 25, 30):
        extra = round(mm * 203 / 25.4)
        assert rows(run(f'ElginFeed={mm}')) == rows(default) + 2 * extra
        assert rows(run(f'ElginFeed={mm} ElginFinishScope=Job')) == rows(default) + extra
    for invalid in ('-1', '31', 'garbage'):
        assert run('ElginFeed=' + invalid) == default
    saved = run('ElginFit=None ElginSaveBottom=On')
    original = run('ElginFit=None ElginSaveBottom=Off')
    assert rows(saved) == 2 * 54 and rows(original) == 400
    # Same image dots with/without trailing whitespace preservation.
    black = lambda es: sum(sum(b.bit_count() for b in x[2]) for x in es if x[0] == 'raster')
    assert black(saved) == black(original) > 0
    assert rows(run('ElginSaveBottom=Off')) > rows(default)
    assert cuts(run(data=subprocess.check_output([str(fixture), '2', '1']))) == 0
    assert cuts(run('ElginFinishScope=Job', data=subprocess.check_output([str(fixture), '2', '1']))) == 0
    print('PASS: multipage cuts, job completion, feed 0–30 mm, invalid options, whitespace, blank jobs')
