import { describe, it, expect } from 'vitest';
import { canonicalHash } from './index.js';

describe('canonicalHash', () => {
  it('produces same hash for semantically identical bodies', () => {
    const a = canonicalHash({ method: 'POST', path: '/v1/orders', contentType: 'application/json', body: { b: 2, a: 1 } });
    const b = canonicalHash({ method: 'POST', path: '/v1/orders', contentType: 'application/json', body: { a: 1, b: 2 } });
    expect(a).toBe(b);
  });

  it('differs when method changes', () => {
    const a = canonicalHash({ method: 'POST', path: '/v1/orders', contentType: 'application/json', body: { a: 1 } });
    const b = canonicalHash({ method: 'PUT', path: '/v1/orders', contentType: 'application/json', body: { a: 1 } });
    expect(a).not.toBe(b);
  });

  it('handles null/undefined bodies deterministically', () => {
    const a = canonicalHash({ method: 'GET', path: '/v1/orders', contentType: 'application/json', body: undefined });
    const b = canonicalHash({ method: 'GET', path: '/v1/orders', contentType: 'application/json', body: null });
    expect(a).toBe(b);
  });
});
