import { createHash, randomBytes } from 'node:crypto';

export function hashSha256Hex(value: string) {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

export function generateAccessToken() {
  return randomBytes(32).toString('base64url');
}

export function generateReference(prefix: string) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = randomBytes(8);
  let suffix = '';
  for (const byte of bytes) {
    suffix += chars[byte % chars.length];
  }
  return `${prefix}-${suffix}`;
}

export function verifyPin(pin: string, storedPinHash: string) {
  if (storedPinHash.startsWith('sha256:')) {
    const expected = storedPinHash.slice('sha256:'.length);
    return hashSha256Hex(pin) === expected;
  }

  if (storedPinHash.startsWith('plain:')) {
    return pin === storedPinHash.slice('plain:'.length);
  }

  return false;
}
