export type Jwk = { kty: 'OKP'; crv: 'Ed25519'; kid: string; x: string };
export type Jwks = { keys: Jwk[] };
export {
  getOrCreateKeyPair,
  signPayloadEd25519,
  verifyPayloadEd25519,
  exportJwk,
  getPublicKeyByKid,
  getPublicJwks,
  rotateKeyPair,
  getPrivateKeyByKid
} from './keys.js';


