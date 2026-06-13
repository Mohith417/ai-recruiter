import crypto from 'crypto';
import { exportJWK, importSPKI, importPKCS8, SignJWT } from 'jose';

class JwksManager {
  private privateKeyPem: string;
  private publicKeyPem: string;
  private jwkPublic: any = null;

  constructor() {
    const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', {
      modulusLength: 2048,
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    });
    this.privateKeyPem = privateKey;
    this.publicKeyPem = publicKey;
  }

  async getJwk() {
    if (!this.jwkPublic) {
      const parsed = await importSPKI(this.publicKeyPem, 'RS256');
      const jwk = await exportJWK(parsed);
      this.jwkPublic = {
        ...jwk,
        kid: 'local-key-1',
        alg: 'RS256',
        use: 'sig',
      };
    }
    return this.jwkPublic;
  }

  async getPublicKey() {
    return importSPKI(this.publicKeyPem, 'RS256');
  }

  async signToken(payload: any, email: string): Promise<string> {
    const privateKey = await importPKCS8(this.privateKeyPem, 'RS256');
    return new SignJWT(payload)
      .setProtectedHeader({ alg: 'RS256', kid: 'local-key-1' })
      .setIssuedAt()
      .setAudience('authenticated')
      .setSubject(email)
      .setExpirationTime('24h')
      .sign(privateKey);
  }
}

export const jwksManager = new JwksManager();
