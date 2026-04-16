# H.I.V.E. Security & Correctness TODO

Generated from code review on 2026-04-16. All findings below have been addressed, dismissed as false positives, or consciously deferred.

## Critical

- [x] **Bind to loopback** — `server.mjs:5913` — `listen(PORT, '127.0.0.1', ...)`. Dashboard is no longer reachable from the LAN.
- [x] **SQL injection: Postgres table count** — `server.mjs:5239` — uses `safeIdent()`.
- [x] **SQL injection: SQLite PRAGMAs** — lines 5022–5039, 5211–5213 — all wrapped in `safeIdent()`.
- [x] **Path traversal: skill read/write** — `server.mjs:2638–2665` — replaced `.includes('.claude')` with `isSafeEditPath()` + separator-anchored `endsWith(sep + 'SKILL.md')`.
- [x] **Path traversal: CLAUDE.md read/write** — `server.mjs:2669–2692` — same treatment; allowed roots = `homedir()` and `BASE_DIR`.
- [x] **SSRF: `/api/proxy` and `/api/proxy/upload`** — host allowlist, stored in user-prefs. First use of a new host triggers a `confirm()` prompt in the Swagger tab; approval adds the host and retries the request. Managed from Settings → API Proxy Allowlist. Only `http`/`https` protocols are accepted.

## Important

- [ ] **Query allow-list bypasses** — `server.mjs:4942` `isQuerySafe` — **left as-is.** Real fix is running under a read-only Postgres role (deployment, not code). The regex is a speed bump, not a lock.
- [x] **SSL disabled silently** — default flipped to `rejectUnauthorized: true`. Per-connection opt-out via `DB_SSL_INSECURE=true` (or `DB_<PREFIX>_SSL_INSECURE=true`). If existing Azure Postgres connections break with cert errors, set that env var.
- [x] ~~**Unhandled `JSON.parse` on proxy headers**~~ — false positive: already inside the handler's try/catch.
- [x] **Unhandled `JSON.parse` on config** — corrupt config now exits with a clear error rather than a raw parse stack.
- [x] ~~**Unhandled `JSON.parse` on credentials**~~ — false positive: already inside `getClaudeOAuthToken()`'s try/catch.
- [x] **Unhandled `JSON.parse` on user prefs** — `readUserPrefs()` returns `{}` on corrupt files with a warning log.
- [x] **Auth on mutation endpoints** — skipped: loopback-only bind makes this unnecessary.
- [x] **Body size cap on `/api/db/query`** — 200KB max, returns 413 above that.

## Advisory

- [x] ~~**`getDbPool` race**~~ — false positive: Node is single-threaded and `new pg.Pool()` is synchronous, so the check-then-set window is atomic.
- [ ] **Spawn error visibility** — deferred.
- [ ] **`doctor.mjs` + `setup.ps1` review** — deferred.

## New helpers in `server.mjs`

- `isSafeEditPath(p)` — path must resolve to within `homedir()` or `BASE_DIR`.
- `safeIdent(name)` — throws unless identifier matches `^[A-Za-z_][A-Za-z0-9_]*$`. Used where bind params aren't possible (Postgres `FROM "schema"."table"`, SQLite `PRAGMA`).
- `checkProxyTarget(url)` — validates proxy targets against the allowlist and protocol whitelist.
- `getProxyAllowlist()` / `saveProxyAllowlist()` — persist the allowlist in user-prefs.

## New endpoints

- `GET /api/proxy/allowlist` — returns `{ hosts: [...] }`
- `POST /api/proxy/allowlist` — body `{ host }` — adds a host
- `DELETE /api/proxy/allowlist/:host` — removes a host

## New env vars

- `DB_SSL_INSECURE` / `DB_<PREFIX>_SSL_INSECURE` — set to `true` if the server's SSL certificate can't be verified against the system CA pool (e.g. self-signed). Only effective when `DB_SSL=true`.

## Migration notes

- **First run after this change:** dashboard listens on `127.0.0.1` only. Access it via `http://localhost:3333`. Remote access (phone, other machines) is no longer possible — by design.
- **First proxy call after this change:** the Swagger tab will ask you to approve each unique host once. Pre-seed the list from Settings → API Proxy Allowlist if desired.
- **DB with self-signed SSL:** if a previously-working DB connection starts failing with a cert error, add `DB_SSL_INSECURE=true` (or the prefixed variant) to `.env`.
