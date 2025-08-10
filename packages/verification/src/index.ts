// Placeholder for future Ed25519/JWKS implementation
export type Jwk = { kty: 'OKP'; crv: 'Ed25519'; kid: string; x: string };
export type Jwks = { keys: Jwk[] };


