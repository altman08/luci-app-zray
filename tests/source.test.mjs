import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

for (const pinnedRelease of [false, true]) {
test(`source updater locks ${pinnedRelease ? 'the configured release' : 'an explicit commit'} with matching metadata`, () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'zray-source-'));
    try {
        const commit = 'ca0df66369b034ce8ecd9cfa5b2d014388ff6617';
        for (const name of ['tools', 'zray', 'mock-bin', 'zray-' + commit])
            fs.mkdirSync(path.join(tmp, name));
        const recipe = fs.readFileSync(new URL('../zray/Makefile', import.meta.url), 'utf8');
        fs.writeFileSync(path.join(tmp, 'zray/Makefile'), recipe);
        fs.copyFileSync(new URL('../tools/update-source.py', import.meta.url), path.join(tmp, 'tools/update-source.py'));
        fs.writeFileSync(path.join(tmp, 'zray-' + commit, 'build.zig.zon'), '.{ .version = "0.5.0" }');
        const archive = path.join(tmp, 'source.tar.gz');
        execFileSync('tar', ['-czf', archive, '-C', tmp, 'zray-' + commit]);
        fs.writeFileSync(path.join(tmp, 'mock-bin/curl'), `#!/bin/sh
case "$*" in
  *api.github.com*) printf '{"sha":"%s"}\\n' "$ZRAY_TEST_COMMIT" ;;
  *) cat "$ZRAY_TEST_ARCHIVE" ;;
esac
`, { mode: 0o755 });
        execFileSync('python3', [path.join(tmp, 'tools/update-source.py'), ...(pinnedRelease ? [] : ['--commit', commit])], {
            env: { ...process.env, PATH: path.join(tmp, 'mock-bin') + ':' + process.env.PATH, ZRAY_TEST_ARCHIVE: archive, ZRAY_TEST_COMMIT: commit }
        });
        const info = JSON.parse(fs.readFileSync(path.join(tmp, 'zray/source-info.json')));
        assert.equal(info.version, pinnedRelease ? '0.5.0' : '0.5.0~ca0df66369b0');
        assert.equal(info.repository, 'yunnysunny/zray');
        assert.equal(info.tag, 'v0.5.0');
        assert.equal(info.commit, commit);
        assert.equal(info.sha256, createHash('sha256').update(fs.readFileSync(archive)).digest('hex'));
        const generated = fs.readFileSync(path.join(tmp, 'zray/Makefile'), 'utf8');
        assert.ok(generated.includes('PKG_VERSION:=' + info.version + '\n'));
        assert.ok(generated.includes('PKG_HASH:=' + info.sha256 + '\n'));
    } finally {
        fs.rmSync(tmp, { recursive: true, force: true });
    }
});
}
