import crypto from 'node:crypto';

export type KeyPair = { kid: string; privateKey: crypto.KeyObject; publicKey: crypto.KeyObject };

function b64url(input: Buffer | string) {
  const buf = Buffer.isBuffer(input) ? input : Buffer.from(input);
  return buf.toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

// Simple in-memory keyring for process lifetime. In production, back this with KMS/HSM and persistent key store.
let activeKid: string | null = null;
const keyring = new Map<string, KeyPair>();

function ensureInitializedFromEnv(): void {
  const kid = process.env.VERIFICATION_KID || 'dev-ed25519';
  const pem = process.env.VERIFICATION_PRIVATE_PEM;
  if (keyring.has(kid)) {
    if (!activeKid) activeKid = kid;
    return;
  }
  if (pem && pem.includes('BEGIN PRIVATE KEY')) {
    const privateKey = crypto.createPrivateKey(pem);
    const publicKey = crypto.createPublicKey(privateKey);
    const pair: KeyPair = { kid, privateKey, publicKey };
    keyring.set(kid, pair);
    activeKid = kid;
    return;
  }
  // Dev fallback: generate a keypair once per process
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
  const pair: KeyPair = { kid, privateKey, publicKey };
  keyring.set(kid, pair);
  activeKid = kid;
}

export function getOrCreateKeyPair(): KeyPair {
  ensureInitializedFromEnv();
  return keyring.get(String(activeKid)) as KeyPair;
}

export function rotateKeyPair(): KeyPair {
  // Non-persistent rotation for tests/dev. In prod, create and activate via KMS and keep prior public keys.
  const kid = `dev-ed25519-${Date.now().toString(36)}`;
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
  const pair: KeyPair = { kid, privateKey, publicKey };
  keyring.set(kid, pair);
  activeKid = kid;
  return pair;
}

export function getPublicKeyByKid(kid: string): crypto.KeyObject | null {
  const pair = keyring.get(kid);
  return pair ? pair.publicKey : null;
}

export function getPrivateKeyByKid(kid: string): crypto.KeyObject | null {
  const pair = keyring.get(kid);
  return pair ? pair.privateKey : null;
}

export function getPublicJwks() {
  const keys = Array.from(keyring.values()).map((p) => exportJwk(p.publicKey, p.kid));
  return { keys };
}

export function signPayloadEd25519(privateKey: crypto.KeyObject, payload: Buffer): string {
  const sig = crypto.sign(null, payload, privateKey);
  return b64url(sig);
}

export function verifyPayloadEd25519(publicKey: crypto.KeyObject, payload: Buffer, signatureB64: string): boolean {
  const sig = Buffer.from(signatureB64.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
  return crypto.verify(null, payload, publicKey, sig);
}

export function exportJwk(publicKey: crypto.KeyObject, kid: string) {
  const jwk = publicKey.export({ format: 'jwk' }) as any;
  return { kty: 'OKP', crv: 'Ed25519', kid, x: jwk.x };
}


