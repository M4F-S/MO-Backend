# Authentication & Authorization

> Comprehensive guide to OAuth 2.0, OIDC, JWT, session management, RBAC, ABAC, and security best practices for production APIs.

## Table of Contents

1. [OAuth 2.0 & OpenID Connect](#1-oauth-20--openid-connect)
2. [JWT (JSON Web Tokens)](#2-jwt-json-web-tokens)
3. [Session Management](#3-session-management)
4. [RBAC & ABAC](#4-rbac--abac)
5. [API Authentication](#5-api-authentication)
6. [Password Security](#6-password-security)
7. [Multi-Factor Authentication](#7-multi-factor-authentication)
8. [Token Storage](#8-token-storage)
9. [Common Vulnerabilities](#9-common-vulnerabilities)
10. [Implementation Patterns](#10-implementation-patterns)

---

## 1. OAuth 2.0 & OpenID Connect

### OAuth 2.0 Flows

| Flow | Use Case | Client Type | Refresh Token | PKCE Required |
|------|----------|-------------|-------------|---------------|
| **Authorization Code** | Web apps, SPAs | Confidential | Yes | Yes (public clients) |
| **PKCE** | Mobile, SPAs | Public | Yes | Required |
| **Client Credentials** | Service-to-service | Confidential | No | N/A |
| **Device Code** | TVs, IoT | Public | Yes | N/A |
| **Implicit** | ⚠️ Deprecated | Public | No | N/A |
| **Password** | ⚠️ Deprecated | Confidential | Yes | N/A |

**Recommended**: Authorization Code + PKCE for all client types. Never use Implicit or Password flows.

### Authorization Code + PKCE Flow

```
┌─────────────┐                                    ┌─────────────┐
│   Client    │                                    │   Server    │
│  (Browser)  │                                    │  (OAuth)    │
└──────┬──────┘                                    └──────┬──────┘
       │                                                │
       │ 1. GET /authorize?response_type=code          │
       │    &client_id=xxx&redirect_uri=...            │
       │    &code_challenge=abc&code_challenge_method=S256│
       │───────────────────────────────────────────────> │
       │                                                │
       │ 2. Redirect to login / consent                 │
       │<───────────────────────────────────────────────│
       │                                                │
       │ 3. POST /token                                 │
       │    grant_type=authorization_code               │
       │    &code=xxx&code_verifier=xxx                 │
       │───────────────────────────────────────────────>│
       │                                                │
       │ 4. { access_token, refresh_token, id_token }   │
       │<───────────────────────────────────────────────│
```

### OIDC (OpenID Connect)

OIDC adds identity layer on top of OAuth 2.0:

```json
// ID Token (JWT)
{
  "iss": "https://auth.example.com",
  "sub": "user_123456",
  "aud": "my-client-id",
  "exp": 1705316400,
  "iat": 1705312800,
  "auth_time": 1705312800,
  "nonce": "random_value",
  "name": "John Doe",
  "email": "john@example.com",
  "email_verified": true,
  "picture": "https://example.com/photo.jpg"
}
```

### OAuth 2.1 (Latest)

- PKCE required for all authorization code flows
- Redirect URI exact matching (no wildcards)
- State parameter required for all flows
- Refresh tokens must be sender-constrained or one-time use
- No implicit flow, no password grant

---

## 2. JWT (JSON Web Tokens)

### JWT Structure

```
Header.Payload.Signature

Header: { "alg": "RS256", "typ": "JWT" }
Payload: { "sub": "user_123", "iss": "auth.example.com", ... }
Signature: HMAC-SHA256(Header + "." + Payload, secret)
```

### JWT Best Practices

**Signing Algorithms**:
| Algorithm | Use Case | Security |
|-----------|----------|----------|
| **RS256** | Production APIs (asymmetric) | High |
| **ES256** | Mobile, constrained devices | High, smaller signatures |
| **HS256** | Internal microservices (shared secret) | Medium (secret rotation hard) |
| **None** | ⚠️ Never use | None |
| **RS512** | Legacy compatibility | High, but slower than RS256 |

**Token Design**:
```json
{
  "sub": "user_123456789",      // Subject (user ID)
  "iss": "https://auth.example.com", // Issuer
  "aud": "api.example.com",     // Audience (your API)
  "exp": 1705316400,            // Expiration (15 min)
  "iat": 1705312800,            // Issued at
  "jti": "token_abc123",        // Unique token ID (for revocation)
  "scope": "read write",        // OAuth scopes
  "role": "admin",              // Application role
  "permissions": ["users:read", "orders:write"] // Fine-grained
}
```

**Validation Rules**:
1. Verify signature (always)
2. Check `iss` matches expected issuer
3. Check `aud` matches your API
4. Check `exp` not expired (with clock skew tolerance: 60s)
5. Check `nbf` if present (not before)
6. Check `iat` not in future (replay prevention)
7. Verify `jti` not in revocation list (if using revocation)

### JWT Implementation (Node.js)

```typescript
import { SignJWT, jwtVerify, importJWK } from 'jose';

// Generate signing keys (run once, store securely)
const { publicKey, privateKey } = await crypto.subtle.generateKeyPair(
  { name: 'RSA-PSS', hash: 'SHA-256', modulusLength: 2048 },
  true,
  ['sign', 'verify']
);

// Sign token
const token = await new SignJWT({
  sub: user.id,
  role: user.role,
  permissions: user.permissions,
})
  .setProtectedHeader({ alg: 'RS256' })
  .setIssuedAt()
  .setIssuer('https://auth.example.com')
  .setAudience('api.example.com')
  .setExpirationTime('15m')
  .setJti(crypto.randomUUID())
  .sign(privateKey);

// Verify token
const { payload } = await jwtVerify(token, publicKey, {
  issuer: 'https://auth.example.com',
  audience: 'api.example.com',
  clockTolerance: 60,
  maxTokenAge: '15m',
});
```

### Refresh Tokens

```typescript
interface TokenPair {
  accessToken: string;  // Short-lived (15 min), JWT
  refreshToken: string; // Long-lived (7 days), opaque, stored in DB
}

// Refresh token rotation
async function refreshAccessToken(refreshToken: string): Promise<TokenPair> {
  const stored = await db.refreshTokens.findUnique({ where: { token: refreshToken } });
  
  if (!stored || stored.revoked || stored.expiresAt < new Date()) {
    throw new UnauthorizedError('Invalid refresh token');
  }
  
  // Detect token reuse (compromised refresh token)
  if (stored.used) {
    // Revoke all tokens for this user — possible breach
    await db.refreshTokens.updateMany({
      where: { userId: stored.userId },
      data: { revoked: true },
    });
    throw new UnauthorizedError('Token reuse detected');
  }
  
  // Mark as used, issue new pair
  await db.refreshTokens.update({ where: { id: stored.id }, data: { used: true } });
  
  const user = await db.users.findById(stored.userId);
  return generateTokenPair(user);
}
```

---

## 3. Session Management

### Stateful vs Stateless Sessions

| Approach | Storage | Scale | Security | Use Case |
|----------|---------|-------|----------|----------|
| **Stateful (DB)** | Server-side | Requires DB lookup | High (revocation) | Web apps, admin panels |
| **Stateless (JWT)** | Client-side | No DB lookup | Medium (no instant revocation) | APIs, mobile |
| **Hybrid** | Redis + short JWT | Redis lookup | High | Best of both |

### Stateful Session (Redis)

```typescript
interface Session {
  id: string;
  userId: string;
  createdAt: Date;
  expiresAt: Date;
  lastActiveAt: Date;
  ip: string;
  userAgent: string;
}

class SessionManager {
  async create(userId: string, ip: string, userAgent: string): Promise<Session> {
    const session: Session = {
      id: crypto.randomUUID(),
      userId,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      lastActiveAt: new Date(),
      ip,
      userAgent,
    };
    
    await redis.setex(`session:${session.id}`, 7 * 24 * 60 * 60, JSON.stringify(session));
    return session;
  }

  async validate(sessionId: string): Promise<Session | null> {
    const data = await redis.get(`session:${session.id}`);
    if (!data) return null;
    
    const session = JSON.parse(data);
    if (new Date(session.expiresAt) < new Date()) {
      await this.revoke(sessionId);
      return null;
    }
    
    // Update last active
    session.lastActiveAt = new Date();
    await redis.setex(`session:${session.id}`, 7 * 24 * 60 * 60, JSON.stringify(session));
    
    return session;
  }

  async revoke(sessionId: string): Promise<void> {
    await redis.del(`session:${sessionId}`);
    // Also revoke all associated tokens
  }

  async revokeAllForUser(userId: string): Promise<void> {
    const keys = await redis.keys(`session:*`);
    for (const key of keys) {
      const session = JSON.parse(await redis.get(key));
      if (session.userId === userId) {
        await redis.del(key);
      }
    }
  }
}
```

---

## 4. RBAC & ABAC

### RBAC (Role-Based Access Control)

```typescript
// Role definitions
enum Role {
  ADMIN = 'admin',
  USER = 'user',
  GUEST = 'guest',
}

const ROLE_PERMISSIONS: Record<Role, string[]> = {
  [Role.ADMIN]: ['*'], // Wildcard
  [Role.USER]: [
    'users:read',
    'users:update',
    'orders:read',
    'orders:create',
    'products:read',
  ],
  [Role.GUEST]: [
    'products:read',
  ],
};

function hasPermission(role: Role, permission: string): boolean {
  const permissions = ROLE_PERMISSIONS[role];
  return permissions.includes('*') || permissions.includes(permission);
}

// Middleware
function requirePermission(permission: string) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!hasPermission(req.user.role, permission)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
}

// Usage
app.get('/api/users', authenticate, requirePermission('users:read'), getUsers);
app.delete('/api/users/:id', authenticate, requirePermission('users:delete'), deleteUser);
```

### ABAC (Attribute-Based Access Control)

```typescript
// Policy engine
interface AccessPolicy {
  subject: string;    // user:role, user:id
  resource: string;   // resource:type:id
  action: string;     // read, write, delete
  conditions?: {       // Dynamic conditions
    timeRange?: { start: string; end: string };
    ipWhitelist?: string[];
    mfaRequired?: boolean;
    resourceOwner?: boolean; // Owner can always access
  };
}

function evaluatePolicy(
  user: User,
  resource: Resource,
  action: string,
  policies: AccessPolicy[]
): boolean {
  for (const policy of policies) {
    const subjectMatch = policy.subject === `user:${user.id}` || policy.subject === `role:${user.role}`;
    const resourceMatch = policy.resource === `resource:${resource.type}:*` || policy.resource === `resource:${resource.type}:${resource.id}`;
    const actionMatch = policy.action === action || policy.action === '*';
    
    if (subjectMatch && resourceMatch && actionMatch) {
      if (policy.conditions) {
        if (policy.conditions.resourceOwner && resource.ownerId !== user.id) continue;
        if (policy.conditions.mfaRequired && !user.mfaEnabled) continue;
        if (policy.conditions.ipWhitelist && !policy.conditions.ipWhitelist.includes(user.ip)) continue;
      }
      return true;
    }
  }
  return false;
}

// Example: User can only delete their own orders
const policies: AccessPolicy[] = [
  { subject: 'role:admin', resource: 'resource:order:*', action: '*' },
  { subject: 'role:user', resource: 'resource:order:*', action: 'read' },
  { subject: 'role:user', resource: 'resource:order:*', action: 'delete', conditions: { resourceOwner: true } },
];
```

### Permission Hierarchy

```
admin
├── users:*
│   ├── users:read
│   ├── users:create
│   ├── users:update
│   └── users:delete
├── orders:*
│   ├── orders:read
│   ├── orders:create
│   ├── orders:update
│   └── orders:delete
└── products:*
    ├── products:read
    ├── products:create
    ├── products:update
    └── products:delete

user
├── users:read
├── users:update (own)
├── orders:read (own)
├── orders:create
└── products:read
```

---

## 5. API Authentication

### Authentication Methods

| Method | Use Case | Security | Complexity |
|--------|----------|----------|------------|
| **JWT Bearer** | SPAs, mobile, APIs | Medium | Low |
| **Session Cookie** | Web apps, server-rendered | High | Medium |
| **API Key** | Service-to-service, third-party | Medium | Low |
| **mTLS** | Microservices, high security | High | High |
| **OAuth 2.0** | Third-party integrations | High | High |
| **HMAC** | Webhooks, legacy | Medium | Medium |

### API Key Authentication

```typescript
// API key format: ak_live_abc123... (32+ chars, random)
// Store hashed in DB: bcrypt(apiKey, 10)

async function authenticateApiKey(req: Request, res: Response, next: NextFunction) {
  const apiKey = req.headers['x-api-key'];
  if (!apiKey) return res.status(401).json({ error: 'API key required' });
  
  const hashedKey = crypto.createHash('sha256').update(apiKey).digest('hex');
  const keyRecord = await db.apiKeys.findUnique({ where: { hashedKey } });
  
  if (!keyRecord || keyRecord.revoked || keyRecord.expiresAt < new Date()) {
    return res.status(401).json({ error: 'Invalid API key' });
  }
  
  // Update last used
  await db.apiKeys.update({ where: { id: keyRecord.id }, data: { lastUsedAt: new Date() } });
  
  req.user = { id: keyRecord.userId, role: keyRecord.role, type: 'api_key' };
  next();
}
```

### mTLS (Mutual TLS)

```typescript
// Server requires client certificate
const server = https.createServer({
  key: fs.readFileSync('server-key.pem'),
  cert: fs.readFileSync('server-cert.pem'),
  ca: fs.readFileSync('ca-cert.pem'), // Trust this CA
  requestCert: true,                  // Require client cert
  rejectUnauthorized: true,             // Reject invalid certs
}, app);

// Express middleware to extract client identity
app.use((req: Request, res: Response, next: NextFunction) => {
  const cert = req.socket.getPeerCertificate();
  if (cert && cert.subject) {
    req.client = {
      cn: cert.subject.CN,
      org: cert.subject.O,
      fingerprint: cert.fingerprint,
    };
  }
  next();
});
```

---

## 6. Password Security

### Password Hashing

| Algorithm | Work Factor | Memory | Recommendation |
|-----------|-------------|--------|----------------|
| **Argon2id** | 3 iterations, 64MB | 64MB | ⭐ Recommended (2024) |
| **bcrypt** | 12 rounds | 4KB | Good, widely supported |
| **scrypt** | N=32768, r=8, p=1 | 32MB | Good, GPU resistant |
| **PBKDF2** | 600k iterations | 4KB | FIPS compliant, slower |
| **MD5/SHA1** | N/A | N/A | ⚠️ Never use |

### Argon2 Implementation (Node.js)

```typescript
import argon2 from 'argon2';

// Hash password
const hash = await argon2.hash(password, {
  type: argon2id,           // Memory-hard, GPU resistant
  memoryCost: 65536,        // 64 MB
  timeCost: 3,              // 3 iterations
  parallelism: 4,           // 4 parallel threads
  saltLength: 16,         // 16 bytes random salt
  hashLength: 32,           // 32 byte output
});

// Verify password
const valid = await argon2.verify(hash, password);
if (!valid) throw new UnauthorizedError('Invalid credentials');
```

### Password Policy

- **Minimum length**: 12 characters (NIST 2024)
- **Complexity**: Not required (NIST says length > complexity)
- **Common passwords**: Reject top 10k passwords (HaveIBeenPwned API)
- **Breached detection**: Check against HIBP on registration/login
- **Rate limiting**: Max 5 attempts per 15 minutes per IP/user
- **Lockout**: Progressive delay (5s, 10s, 30s, 60s) — not permanent lockout

---

## 7. Multi-Factor Authentication

### MFA Methods (Ranked by Security)

| Method | Security | Usability | Cost | Recommendation |
|--------|----------|-----------|------|----------------|
| **WebAuthn/FIDO2** | Very High | High | Medium | ⭐ Best for security |
| **TOTP (Auth App)** | High | High | Free | ⭐ Best balance |
| **Push Notification** | Medium | Very High | Low | Good UX, check sender |
| **SMS** | Low | High | Low | ⚠️ Vulnerable to SIM swap |
| **Email** | Low | Medium | Free | ⚠️ Phishable |
| **Backup Codes** | High | Low | Free | Required as fallback |

### TOTP Implementation

```typescript
import { authenticator } from 'otplib';

// Generate secret
const secret = authenticator.generateSecret(); // Base32 string

// Generate QR code for setup
const otpauthUrl = authenticator.keyuri(user.email, 'MyApp', secret);
// → Show QR code to user

// Verify TOTP
const isValid = authenticator.verify({ token: userInput, secret });
if (!isValid) throw new UnauthorizedError('Invalid code');

// Store encrypted secret in DB
await db.users.update({
  where: { id: user.id },
  data: {
    mfaSecret: encrypt(secret), // AES-256-GCM
    mfaEnabled: true,
    mfaBackupCodes: generateBackupCodes(), // 10 codes, hashed
  },
});
```

---

## 8. Token Storage

### Browser Storage Security

| Storage | XSS Risk | CSRF Risk | Size | Use Case |
|---------|----------|-----------|------|----------|
| **HttpOnly Cookie** | Safe | Medium | 4KB | Sessions, refresh tokens |
| **Memory (JS variable)** | Safe | Safe | N/A | Access tokens (short-lived) |
| **localStorage** | Vulnerable | Safe | 5MB | ⚠️ Never for sensitive tokens |
| **sessionStorage** | Vulnerable | Safe | 5MB | ⚠️ Never for sensitive tokens |
| **IndexedDB** | Vulnerable | Safe | Large | Non-sensitive data |

### Recommended Token Storage Pattern

```
┌─────────────────────────────────────────┐
│              Browser                     │
│  ┌─────────────────────────────────────┐│
│  │  Memory (JavaScript)                ││
│  │  • Access token (JWT, 15 min)       ││
│  └─────────────────────────────────────┘│
│  ┌─────────────────────────────────────┐│
│  │  HttpOnly Cookie                    ││
│  │  • Refresh token (opaque, 7 days)   ││
│  │  • SameSite=Strict, Secure          ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

### Cookie Configuration

```http
Set-Cookie: refresh_token=abc123; HttpOnly; Secure; SameSite=Strict; Path=/api/auth/refresh; Max-Age=604800; Domain=api.example.com
```

---

## 9. Common Vulnerabilities

| Vulnerability | Prevention |
|---------------|------------|
| **Token Theft** | Short-lived tokens, rotation, binding to device/session |
| **Replay Attacks** | `jti` claim, nonce, request signing |
| **CSRF** | SameSite cookies, anti-CSRF tokens for state changes |
| **XSS** | HttpOnly cookies, CSP headers, input sanitization |
| **Session Hijacking** | IP binding, user-agent fingerprinting, anomaly detection |
| **Credential Stuffing** | Rate limiting, CAPTCHA, breached password detection |
| **JWT None Algorithm** | Reject `alg: none`, whitelist allowed algorithms |
| **Weak Secrets** | 256+ bit keys, rotate regularly, use Key Vault |
| **Information Leakage** | Generic error messages, no stack traces in production |
| **Timing Attacks** | Constant-time comparison for secrets, tokens |

### BOLA (Broken Object Level Authorization)

```typescript
// ❌ Vulnerable: Any authenticated user can access any resource
app.get('/api/orders/:id', authenticate, async (req, res) => {
  const order = await db.orders.findById(req.params.id);
  res.json(order); // No ownership check!
});

// ✅ Secure: Verify ownership
app.get('/api/orders/:id', authenticate, async (req, res) => {
  const order = await db.orders.findById(req.params.id);
  if (!order || order.userId !== req.user.id) {
    return res.status(404).json({ error: 'Not found' }); // 404, not 403
  }
  res.json(order);
});
```

---

## 10. Implementation Patterns

### NestJS Guard (RBAC + Ownership)

```typescript
@Injectable()
class OwnershipGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const resource = this.reflector.get<string>('resource', context.getHandler());
    const action = this.reflector.get<string>('action', context.getHandler());
    const user = context.switchToHttp().getRequest().user;
    const resourceId = context.switchToHttp().getRequest().params.id;

    // Check ownership
    if (resource && resourceId) {
      const service = context.getClass().instance as any;
      const item = service.findById(resourceId);
      if (item.ownerId !== user.id && user.role !== 'admin') {
        return false;
      }
    }

    // Check permission
    return hasPermission(user.role, `${resource}:${action}`);
  }
}

// Usage
@Controller('orders')
@UseGuards(AuthGuard('jwt'), OwnershipGuard)
export class OrderController {
  @Get(':id')
  @SetMetadata('resource', 'orders')
  @SetMetadata('action', 'read')
  findOne(@Param('id') id: string) {
    return this.orderService.findById(id);
  }

  @Delete(':id')
  @SetMetadata('resource', 'orders')
  @SetMetadata('action', 'delete')
  remove(@Param('id') id: string) {
    return this.orderService.delete(id);
  }
}
```

### FastAPI Dependency (OAuth2 + JWT)

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from pydantic import BaseModel

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token")

class TokenData(BaseModel):
    user_id: str | None = None
    role: str | None = None

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
        token_data = TokenData(user_id=user_id, role=payload.get("role"))
    except JWTError:
        raise credentials_exception

    user = await get_user(token_data.user_id)
    if user is None:
        raise credentials_exception
    return user

async def require_permission(permission: str):
    async def permission_checker(current_user: User = Depends(get_current_user)):
        if not has_permission(current_user.role, permission):
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return current_user
    return permission_checker

# Usage
@app.get("/users")
async def list_users(
    current_user: User = Depends(require_permission("users:read"))
):
    return await get_users()
```

### Go Middleware (JWT + RBAC)

```go
package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

type contextKey string
const userContextKey contextKey = "user"

type UserClaims struct {
	UserID      string   `json:"sub"`
	Role        string   `json:"role"`
	Permissions []string `json:"permissions"`
	jwt.RegisteredClaims
}

func JWTAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		tokenString := extractBearerToken(r)
		if tokenString == "" {
			http.Error(w, `{"error":"Unauthorized"}`, http.StatusUnauthorized)
			return
		}

		token, err := jwt.ParseWithClaims(tokenString, &UserClaims{}, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return publicKey, nil
		})
		if err != nil || !token.Valid {
			http.Error(w, `{"error":"Unauthorized"}`, http.StatusUnauthorized)
			return
		}

		claims := token.Claims.(*UserClaims)
		ctx := context.WithValue(r.Context(), userContextKey, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func RequirePermission(permission string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims := r.Context().Value(userContextKey).(*UserClaims)
			if !hasPermission(claims.Role, permission) {
				http.Error(w, `{"error":"Forbidden"}`, http.StatusForbidden)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func extractBearerToken(r *http.Request) string {
	auth := r.Header.Get("Authorization")
	if auth == "" { return "" }
	parts := strings.SplitN(auth, " ", 2)
	if len(parts) != 2 || parts[0] != "Bearer" { return "" }
	return parts[1]
}
```

## References

- [OAuth 2.1 Specification](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1-11)
- [OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html)
- [JWT Best Practices (RFC 8725)](https://datatracker.ietf.org/doc/html/rfc8725)
- [NIST Digital Identity Guidelines](https://pages.nist.gov/800-63-3/)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)
- [Passkeys / WebAuthn](https://webauthn.guide/)
- [Have I Been Pwned](https://haveibeenpwned.com/API/v3)
