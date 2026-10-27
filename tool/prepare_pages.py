"""Prepare the compiled Flutter directory for GitHub Pages; never edits source."""
from pathlib import Path
import re


def prepare(root: Path) -> None:
    site = root / 'build/web'
    if not (site / 'main.dart.js').is_file():
        raise ValueError('Build Flutter Web before preparing Pages.')
    cname = root / 'web/CNAME'
    deployed = site / 'CNAME'
    if cname.exists():
        domain = cname.read_text().strip()
        if not re.fullmatch(r'(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}', domain):
            raise ValueError('CNAME must contain one DNS hostname, without scheme or path.')
        deployed.write_text(domain.lower() + '\n')
    else:
        deployed.unlink(missing_ok=True)
    (site / '.nojekyll').touch()
    # Flutter uses in-memory routes, so the Pages root is the sole entrypoint.
    print('Pages artifacts prepared; deployment and DNS are separate steps.')


if __name__ == '__main__':
    prepare(Path(__file__).resolve().parent.parent)
