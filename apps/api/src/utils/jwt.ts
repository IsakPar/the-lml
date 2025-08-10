import jwt from 'jsonwebtoken';
import type { SignOptions, Secret } from 'jsonwebtoken';

export type JwtClaims = {
  sub: string;
  userId?: string;
  clientId?: string;
  orgId?: string;
  brandId?: string;
  salesChannelId?: string;
  role?: string;
  permissions?: string[];
  tokenType: 'access' | 'refresh';
};

export class JwtService {
  private readonly secret: string;
  private readonly issuer = 'thankful-api';
  private readonly audience = 'thankful-clients';

  constructor() {
    this.secret = process.env.JWT_SECRET || 'dev-secret-not-for-production';
  }

  signAccess(claims: Omit<JwtClaims, 'tokenType'>, expiresIn: SignOptions['expiresIn'] = '15m'): string {
    const options: SignOptions = {
      issuer: this.issuer,
      audience: this.audience,
      algorithm: 'HS256',
      expiresIn,
    };
    return jwt.sign({ ...claims, tokenType: 'access' }, this.secret as Secret, options);
  }

  signRefresh(claims: Omit<JwtClaims, 'tokenType'>, expiresIn: SignOptions['expiresIn'] = '7d') {
    const options: SignOptions = {
      issuer: this.issuer,
      audience: this.audience,
      algorithm: 'HS256',
      expiresIn,
    };
    return jwt.sign({ ...claims, tokenType: 'refresh' }, this.secret as Secret, options);
  }

  verify(token: string): JwtClaims {
    return jwt.verify(token, this.secret as Secret, {
      issuer: this.issuer,
      audience: this.audience,
      algorithms: ['HS256']
    }) as JwtClaims;
  }
}

export function extractBearer(authorization?: string): string | null {
  if (!authorization) return null;
  const [type, token] = authorization.split(' ');
  if (type !== 'Bearer' || !token) return null;
  return token;
}


