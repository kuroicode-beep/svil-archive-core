// native_binding.test.ts — better-sqlite3 native binding 존재 확인

import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

import Database from 'better-sqlite3';

const sidecarRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const nativeBindingPath = join(
  sidecarRoot,
  'node_modules',
  'better-sqlite3',
  'build',
  'Release',
  'better_sqlite3.node',
);

test('better_sqlite3.node exists on disk', () => {
  assert.equal(
    existsSync(nativeBindingPath),
    true,
    `missing native binding: ${nativeBindingPath}`,
  );
});

test('better-sqlite3 opens an in-memory database', () => {
  const db = new Database(':memory:');
  try {
    assert.deepEqual(db.prepare('SELECT 1 AS value').get(), { value: 1 });
  } finally {
    db.close();
  }
});
