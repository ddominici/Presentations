import test from 'node:test';
import assert from 'node:assert/strict';
import { hashEmbedding, tokenize, DIMENSIONS, toVectorLiteral } from '../src/embedding.js';

const cos = (a, b) => a.reduce((s, v, i) => s + v * b[i], 0);

test('embedding: dimensione fissa, normalizzato e deterministico', () => {
  const a = hashEmbedding('notebook leggero per viaggiare');
  assert.equal(a.length, DIMENSIONS);
  assert.ok(Math.abs(cos(a, a) - 1) < 1e-9);
  assert.deepEqual(a, hashEmbedding('notebook leggero per viaggiare'));
});

test('embedding: testi affini più vicini di testi estranei', () => {
  const q = hashEmbedding('computer portatile per lavorare in viaggio');
  const notebook = hashEmbedding('Notebook UltraSlim. Computer portatile leggero per chi lavora in mobilità');
  const lamp = hashEmbedding('Lampada da scrivania LED con ricarica wireless');
  assert.ok(cos(q, notebook) > cos(q, lamp));
});

test('tokenize: accenti e stop word', () => {
  assert.deepEqual(tokenize('Il caffè è già pronto'), ['caffe', 'gia', 'pronto']);
});

test('formato letterale vector', () => {
  assert.equal(toVectorLiteral([0.1234567, -1]), '[0.123457,-1]');
});
