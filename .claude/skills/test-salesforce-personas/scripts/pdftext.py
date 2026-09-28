"""Print the text of a generated file (ContentVersion) so its content can be checked.

Usage: python pdftext.py <ContentVersionId> [search-text] [chars]
Env:   SF_ORG (sf CLI alias, required), SF_API_VERSION (default 62.0)
Needs: pip install pypdf
"""
import os
import subprocess
import sys
import tempfile

import pypdf

org = os.environ.get('SF_ORG') or sys.exit('set SF_ORG to the sf CLI org alias')
api = os.environ.get('SF_API_VERSION', '62.0')
cv = sys.argv[1]
needle = sys.argv[2] if len(sys.argv) > 2 else None
n = int(sys.argv[3]) if len(sys.argv) > 3 else 800

out = os.path.join(tempfile.gettempdir(), f'cv_{cv}.pdf')
subprocess.run(['sf', 'api', 'request', 'rest', f'/services/data/v{api}/sobjects/ContentVersion/{cv}/VersionData',
                '-o', org, '-S', out], capture_output=True, text=True, shell=(os.name == 'nt'))
text = '\n'.join(p.extract_text() or '' for p in pypdf.PdfReader(out).pages)
if needle:
    i = text.find(needle)
    text = text[i:i + n] if i >= 0 else f'[{needle!r} not found]\n' + text[:n]
sys.stdout.reconfigure(encoding='utf-8')
print(text)
