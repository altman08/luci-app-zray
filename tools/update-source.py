#!/usr/bin/env python3
"""Resolve the configured release tag once and lock the SDK and standalone recipes to that source."""
import argparse
import hashlib
import io
import json
import pathlib
import re
import subprocess
import tarfile

root = pathlib.Path(__file__).resolve().parents[1]
recipe = root / 'zray/Makefile'
text = recipe.read_text(encoding='utf-8')

def value(key):
    return re.search(r'^' + key + r':=(.+)$', text, re.M).group(1)

def fetch(url):
    return subprocess.check_output(['curl', '-fsSL', '--retry', '3', '--max-time', '120', url])

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--commit', help='Use a specific commit instead of resolving the configured release tag')
args = parser.parse_args()
repo, tag = value('PKG_SOURCE_REPO'), value('PKG_SOURCE_TAG')
commit = args.commit or json.loads(fetch('https://api.github.com/repos/' + repo + '/commits/' + tag))['sha']
if not re.fullmatch(r'[a-f0-9]{40}', commit):
    raise ValueError('Expected a full Git commit SHA')
archive = fetch('https://codeload.github.com/' + repo + '/tar.gz/' + commit)
digest = hashlib.sha256(archive).hexdigest()
with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as source:
    metadata = source.extractfile('zray-' + commit + '/build.zig.zon').read().decode('utf-8')
version = re.search(r'\.version\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)"', metadata).group(1)
# APK's ~ component accepts a hexadecimal commit hash, not a git. prefix.
if args.commit:
    version += '~' + commit[:12]
elif tag != 'v' + version:
    raise ValueError('Release tag does not match the source version')
for key, val in [('PKG_VERSION', version), ('PKG_SOURCE_VERSION', commit), ('PKG_HASH', digest)]:
    text, count = re.subn(r'^' + key + r':=.+$', key + ':=' + val, text, flags=re.M)
    assert count == 1, key
recipe.write_text(text, encoding='utf-8')
info = {'repository': repo, 'tag': tag, 'commit': commit, 'sha256': digest, 'version': version}
(root / 'zray/source-info.json').write_text(json.dumps(info, indent=2) + '\n', encoding='utf-8')
print(json.dumps(info, indent=2))
