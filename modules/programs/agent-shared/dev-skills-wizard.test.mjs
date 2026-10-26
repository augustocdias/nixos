import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const template = readFileSync(new URL('./dev-skills/wizard/template.sh', import.meta.url), 'utf8');

for (const configured of [true, false]) {
  test(`wizard GitHub writes ${configured ? 'target explicit repository' : 'skip without a repository'}`, () => {
    const dir = mkdtempSync(join(tmpdir(), 'wizard-repository-'));
    try {
      const capture = join(dir, 'calls.jsonl');
      const library = join(dir, 'wizard.sh');
      writeFileSync(library, template.slice(0, template.lastIndexOf('\nrun_wizard "$@"; exit')));
      writeFileSync(join(dir, 'gh'), `#!${process.execPath}
import fs from 'node:fs';
fs.appendFileSync(process.env.CAPTURE, JSON.stringify(process.argv.slice(2)) + '\\n');
if (process.argv[2] === 'secret') fs.readFileSync(0);
`, { mode: 0o755 });
      const result = spawnSync('bash', ['-c', `
source "$1"
unset GH_REPO
${configured ? "GH_REPO=owner/intended" : ''}
set_secret PUBLIC_SECRET public-fixture
set_var PUBLIC_VARIABLE public-fixture
`, 'fixture', library], {
        cwd: tmpdir(),
        env: { ...process.env, PATH: `${dir}:${process.env.PATH}`, CAPTURE: capture },
        encoding: 'utf8',
      });
      assert.equal(result.status, 0, result.stderr);
      if (!configured) {
        assert.match(result.stdout, /skipped GitHub secret/);
        assert.match(result.stdout, /skipped GitHub variable/);
        return;
      }
      const writes = readFileSync(capture, 'utf8').trim().split('\n').map(JSON.parse)
        .filter(args => args[0] !== 'auth');
      assert.deepEqual(writes, [
        ['secret', 'set', 'PUBLIC_SECRET', '--repo', 'owner/intended'],
        ['variable', 'set', 'PUBLIC_VARIABLE', '--body', 'public-fixture', '--repo', 'owner/intended'],
      ]);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
}
