import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('directory')
args = parser.parse_args()
root = Path(args.directory)
if not (root / 'index.html').is_file():
    parser.error('В каталоге нет index.html: сначала выполните flutter build web')
before = sum(p.stat().st_size for p in root.rglob('*') if p.is_file())
removed = []
for file in root.rglob('*'):
    if file.is_file() and file.suffix in ('.symbols', '.map'):
        removed.append({'file': str(file.relative_to(root)), 'bytes': file.stat().st_size})
        file.unlink()
(root / '404.html').write_bytes((root / 'index.html').read_bytes())
(root / '.nojekyll').touch()
after = sum(p.stat().st_size for p in root.rglob('*') if p.is_file())
print(json.dumps({'beforeBytes': before, 'afterBytes': after, 'savedBytes': before - after, 'removed': removed}, ensure_ascii=False, indent=2))
