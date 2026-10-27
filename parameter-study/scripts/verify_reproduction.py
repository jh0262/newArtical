"""Compare a clean, regenerated package directory with the completed study."""
from pathlib import Path
import hashlib
import json
import re
import sys
import numpy as np
from PIL import Image
from pypdf import PdfReader

R = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    stage = Path(sys.argv[1]).resolve()
    assert stage != R and stage.is_dir()
    csvs = [f'{phase}_{kind}.csv' for phase in ['screen', 'confirm']
            for kind in ['summary', 'statistics', 'bootstrap']] + ['confirm_stability.csv']
    records = []
    for name in csvs:
        a, b = R/'data'/name, stage/'data'/name
        assert a.read_bytes() == b.read_bytes(), name
        records.append({'file': 'data/'+name, 'check': 'byte_identical', 'sha256': digest(a)})
    raster = []
    for a in sorted((R/'figures').glob('*.png')):
        b = stage/'figures'/a.name
        aa, bb = np.array(Image.open(a)), np.array(Image.open(b))
        assert aa.shape == bb.shape, a.name
        delta = np.abs(aa.astype(int)-bb.astype(int))
        count = int(np.any(delta != 0, axis=2).sum())
        if count:
            # Accept raster variation only when its complete PDF drawing stream is identical.
            va = PdfReader(a.with_suffix('.pdf')).pages[0].get_contents().get_data()
            vb = PdfReader(b.with_suffix('.pdf')).pages[0].get_contents().get_data()
            assert va == vb and count/(aa.shape[0]*aa.shape[1]) < .0001 and delta.mean() < .001, a.name
        record = {'file': 'figures/'+a.name, 'check': 'pixel_identical' if not count else 'minor_raster_variation_with_identical_pdf_drawing_stream',
                  'different_pixels': count, 'maximum_channel_difference': int(delta.max()), 'mean_absolute_channel_difference': float(delta.mean())}
        records.append(record); raster.append(record)
    for a in sorted((R/'figures').glob('*.pdf')):
        b = stage/'figures'/a.name
        at = [page.extract_text() for page in PdfReader(a).pages]
        bt = [page.extract_text() for page in PdfReader(b).pages]
        assert at == bt and len(at) == 1, a.name
        av = PdfReader(a).pages[0].get_contents().get_data()
        bv = PdfReader(b).pages[0].get_contents().get_data()
        # MATLAB can vary glyph positioning; require identical text and every non-text drawing operation.
        geometry = lambda v: re.sub(rb'\bBT\b.*?\bET\b', b'TEXT', v, flags=re.S)
        assert geometry(av) == geometry(bv), a.name
        records.append({'file': 'figures/'+a.name, 'check': 'page_count_text_and_vector_geometry_identical', 'complete_content_stream_identical': av == bv})
    source_files = list((R/'code').rglob('*.m')) + [R/'reproduce_derived.m', R/'scripts/ERAnalysis.m', R/'scripts/ERFigures.m']
    for a in source_files:
        assert a.read_bytes() == (stage/a.relative_to(R)).read_bytes(), str(a)
    portable = json.loads((stage/'audit/independent_verification.json').read_text())
    assert portable['status'] == 'pass' and 'skipped in portable mode' in portable['originals_check']
    result = {'status': 'pass', 'clean_directory': str(stage), 'method': 'new directory containing the same compact-package file selection; MATLAB reproduce_derived, then portable independent Python verification',
              'searches_rerun': 0, 'statistics_csv_identical': len(csvs), 'png_pixel_identical': sum(r['different_pixels'] == 0 for r in raster),
              'png_minor_raster_variation': sum(r['different_pixels'] > 0 for r in raster),
              'pdf_text_pages_vector_geometry_identical': 7, 'identical_source_files': len(source_files),
              'portable_verification': portable, 'checks': records}
    (R/'audit/package_reproduction.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k not in ['checks', 'portable_verification']}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
