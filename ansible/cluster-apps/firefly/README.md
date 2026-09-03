# Firefly III

[Firefly III](https://github.com/firefly-iii/firefly-iii) is a self-hosted
personal finance manager. Installed from the
[official helm charts](https://firefly-iii.github.io/kubernetes/) using the
`firefly-iii-stack` umbrella chart (PostgreSQL + the app + the data importer).

| Host | What |
| --- | --- |
| `https://firefly.<DOMAIN_NAME>` | Firefly III itself |
| `https://firefly-import.<DOMAIN_NAME>` | [Data importer](https://github.com/firefly-iii/data-importer) — CSV, camt.053, Nordigen/GoCardless, SimpleFIN, Spectre |

## Install

The data importer needs a Firefly III Personal Access Token, which can only be
minted from inside a running Firefly III, so the first install is two passes:

```bash
export NAMESPACE=firefly

# 1. Everything. The importer pod will crash-loop until the token exists.
ansible-playbook install.yaml

# 2. Log in to https://firefly.<DOMAIN_NAME>, then Options -> Profile ->
#    "Remote access and tokens" -> Personal Access Token -> Create new token.
#    (NOT the "command line token" — that is a different thing.)
#    Put it in .env as FIREFLY_IMPORTER_ACCESS_TOKEN, re-source, then:
ansible-playbook install.yaml --tags importer
```

Later runs are a single `ansible-playbook install.yaml`. Useful tags: `sso`
(both oauth2-proxy releases and their middlewares) and `importer` (the importer's
token, proxy and middleware).

## Uninstall
```bash
ansible-playbook uninstall.yaml
```

The PVCs (`firefly`, `firefly-db-storage-claim`,
`firefly-db-backup-storage-claim`) and the `firefly-app-key` secret survive the
uninstall — delete them by hand to actually wipe the data. The chart also runs a
`pre-delete` hook that takes a final `pg_dump` into the backup PVC first.

## Environment variables

| Variable | Purpose |
| --- | --- |
| `NAMESPACE` | Kubernetes namespace to install into. |
| `DOMAIN_NAME` | Base domain; the app is served at `firefly.<DOMAIN_NAME>`. |
| `EMAIL` | Becomes `SITE_OWNER` inside Firefly III. |
| `REALM_NAME` | Keycloak realm hosting the firefly client. |
| `KEYCLOAK_HOME_GROUP` | Only members of this group may reach the app. |
| `FIREFLY_CLIENT_ID` | OIDC client ID registered in Keycloak. |
| `FIREFLY_CLIENT_SECRET` | OIDC client secret. |
| `FIREFLY_OAUTH2_COOKIE_SECRET` | Signs the oauth2-proxy session cookie (32 bytes). |
| `FIREFLY_APP_KEY` | Laravel encryption key (**exactly** 32 characters). |
| `FIREFLY_DB_USER` | PostgreSQL role Firefly III connects as; also seeds the database owner. |
| `FIREFLY_DB_PASSWORD` | PostgreSQL password for that role. |
| `FIREFLY_CRON_TOKEN` | Guards `/api/v1/cron/<token>` (**exactly** 32 characters). |
| `FIREFLY_IMPORTER_CLIENT_ID` | OIDC client ID for the data importer. |
| `FIREFLY_IMPORTER_CLIENT_SECRET` | OIDC client secret for the data importer. |
| `FIREFLY_IMPORTER_OAUTH2_COOKIE_SECRET` | Cookie secret for the importer's oauth2-proxy (32 bytes). |
| `FIREFLY_IMPORTER_ACCESS_TOKEN` | Firefly III Personal Access Token the importer authenticates with. |

Generate the four random values once, then keep them in `ansible/.env`:

```bash
for v in FIREFLY_APP_KEY FIREFLY_CRON_TOKEN FIREFLY_DB_PASSWORD \
         FIREFLY_OAUTH2_COOKIE_SECRET FIREFLY_IMPORTER_OAUTH2_COOKIE_SECRET; do
  echo "export $v=$(head -c 64 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)"
done
```

`FIREFLY_IMPORTER_ACCESS_TOKEN` is not random — it comes from Firefly III itself,
see [Data importer](#data-importer) below. The rest are 32 alphanumeric
characters: `FIREFLY_APP_KEY` and
`FIREFLY_CRON_TOKEN` are rejected at any other length, and oauth2-proxy only
accepts a 16, 24 or 32 byte cookie secret.

> **Back up `FIREFLY_APP_KEY` with your database dumps.** Firefly III encrypts
> parts of the database with it; a dump restored without the matching key is
> unreadable.

## Certificates and DNS

`cert-manager.io/cluster-issuer: letsencrypt-prod` — the OVH DNS-01 webhook
issuer installed by [rke2/cert-issuer](../../rke2/cert-issuer/). Nothing
Cloudflare-related is used here: no tunnel ingress, no `origin-ca-issuer`, no
DNS automation. Point **both** `firefly.<DOMAIN_NAME>` and
`firefly-import.<DOMAIN_NAME>` at the cluster on your own DNS server before
running the playbook — the certificates are issued over DNS-01 so they do not
depend on those records, but the apps are obviously unreachable without them.
Each host gets its own certificate (`firefly-tls`, `firefly-importer-tls`).

As per [rke2/README.md](../../rke2/README.md), switch the issuer to
`letsencrypt-staging` in [values.yaml](values.yaml) while you are iterating, and
back to prod once it works, to stay clear of Let's Encrypt rate limits.

## Single sign-on

**Firefly III has no native OIDC support** — as of v6.6.6 the only options are
its own local accounts or `remote_user_guard`, which trusts an identity asserted
by an upstream proxy
([docs](https://docs.firefly-iii.org/how-to/firefly-iii/advanced/authentication/),
[open feature request](https://github.com/firefly-iii/firefly-iii/issues/10662)).
So Keycloak SSO is done the supported way: **oauth2-proxy** does the OIDC dance
and Firefly III trusts the header it produces.

```
browser ──> Traefik ──(forwardAuth)──> oauth2-proxy ──> Keycloak
               │                            │
               │                    202 + X-Auth-Request-Email
               │                            │
               └──> firefly  <──────────────┘  (header copied onto the request)
```

The same three pieces are applied twice — once for Firefly III, once for the
importer — from [templates/sso.yaml](templates/sso.yaml) and
[oauth2-proxy-values.yaml](oauth2-proxy-values.yaml), which are parameterised by
`proxy_name` / `proxy_hostname` so the two stay in step:

1. oauth2-proxy runs with `--upstream=static://202`, so its `/` endpoint answers
   `202` for a valid session and `302 → Keycloak` otherwise. That is what lets
   Traefik hand the login redirect straight back to the browser without the
   `errors` middleware the classic recipe needs.
2. A Traefik `Middleware` (`<proxy_name>-oauth2-auth`) calls that endpoint on every
   request and copies `X-Auth-Request-*` onto the request that reaches the app.
   The chart's ingress references it via the
   `traefik.ingress.kubernetes.io/router.middlewares` annotation.
3. A second `Ingress` maps `/oauth2` to oauth2-proxy **without** the middleware,
   so `/oauth2/callback` can complete. Traefik prefers the longer path prefix, so
   it wins over the chart's `/` rule.

Firefly III then reads `AUTHENTICATION_GUARD_HEADER=HTTP_X_AUTH_REQUEST_EMAIL`.
That is the PHP `$_SERVER` key, not the HTTP header name — the `HTTP_` prefix,
the upper-casing and the `-`→`_` swap are all required, and a mismatch shows up
as `The guard header was unexpectedly empty` in the pod logs.

### Consequences worth knowing

- **Firefly III performs no authentication of its own any more.** No password,
  no MFA, no rate limiting. Anything that reaches the pod without going through
  the middleware is unauthenticated access, so never add an Ingress for this
  service without the `router.middlewares` annotation.
- **Users are created on the fly** from the e-mail in the header, and the *first*
  one to log in becomes the Firefly III owner/admin. Log in yourself first.
- **The API is behind the proxy too**, so Personal Access Tokens and the mobile
  apps will not work as-is. To allow them, add an Ingress for `/api` without the
  middleware — that leaves `/api` protected only by Firefly's own token auth, so
  do it deliberately.
- Signing out of Firefly III clears its session but not the oauth2-proxy cookie,
  so you land straight back in. `https://firefly.<DOMAIN_NAME>/oauth2/sign_out`
  is the real logout.

## Client creation in SSO

**Two** clients, one per host, so you can decide separately who may read your
finances and who may write transactions into them. For each, substitute `<HOST>`
with `firefly.<DOMAIN_NAME>` and then `firefly-import.<DOMAIN_NAME>`:

- Root URL: `https://<HOST>`
- Home URL: `/`
- Valid redirect URIs: `https://<HOST>/oauth2/callback`
- Web origins: `https://<HOST>`
- Client authentication: On
- Authentication flow: Standard flow

Their credentials go to `FIREFLY_CLIENT_ID`/`FIREFLY_CLIENT_SECRET` and
`FIREFLY_IMPORTER_CLIENT_ID`/`FIREFLY_IMPORTER_CLIENT_SECRET` respectively.

The client must expose the `groups` scope, like the TREK and Mealie clients do —
`--allowed-group=/<KEYCLOAK_HOME_GROUP>` in
[oauth2-proxy-values.yaml](oauth2-proxy-values.yaml) is what restricts who gets
in. Drop that argument to let every realm user through.

**Every user needs `Email verified` set to On in Keycloak.** oauth2-proxy rejects
an `id_token` whose email is unverified, and it surfaces as a `500` on
`/oauth2/callback` — not as an access-denied page, so it reads like a broken
deployment. The pod log names it exactly:
`Error redeeming code during OAuth2 callback: email in id_token (...) isn't verified`.
The alternative is `--insecure-oidc-allow-unverified-email=true`, which drops
that check for everyone.

## Data importer

The [data importer](https://github.com/firefly-iii/data-importer) is a separate
app that reads CSV files, camt.053, or a bank connection (GoCardless/Nordigen,
SimpleFIN, Spectre) and posts the transactions into Firefly III over its API.

**It has no authentication of its own.** Its only secret, `AUTO_IMPORT_SECRET`,
guards the unattended `/autoimport` and `/autoupload` endpoints, and those stay
disabled by default — the interactive UI has no login whatsoever. Anyone who can
reach it can write transactions into your Firefly III using the stored token. Its
oauth2-proxy is therefore not optional hardening, it is the only access control
that exists. Never expose it without the `router.middlewares` annotation.

How it is wired:

- `fireflyiii.url: http://firefly:80` — the **in-cluster** Service, deliberately
  not the public URL. This hop bypasses oauth2-proxy, which matters because
  Firefly III's `/api` sits behind the auth middleware and would otherwise reject
  the importer's token-authenticated calls.
- `fireflyiii.vanityUrl: https://firefly.<DOMAIN_NAME>` — used only to build
  links back to Firefly III in the importer's UI.
- `FIREFLY_III_ACCESS_TOKEN` comes from the `firefly-importer-token` Secret,
  created by the playbook from `FIREFLY_IMPORTER_ACCESS_TOKEN`.

### Getting the access token

Chicken-and-egg: the token can only be minted from a running Firefly III, so the
importer crash-loops until you supply one. In Firefly III go to **Options →
Profile → "Remote access and tokens" → Personal Access Token → Create new
token**. Copy it into `.env`, re-source, and run
`ansible-playbook install.yaml --tags importer`.

Use the **Personal Access Token**, not the "command line token" on the same page
— the importer's docs are explicit that the latter is the wrong one and will not
work.

### Importing

Upload a CSV at `https://firefly-import.<DOMAIN_NAME>`, map the columns, and the
importer will offer to download a JSON configuration file. Keep those files: they
make the next import of the same bank's export a one-click job. To ship them with
the deployment instead of uploading each time, add them to `importer.config.files`
in [values.yaml](values.yaml) — they land in
`/var/www/html/storage/configurations`.

## Notes

- **Chart versions are pinned** (`firefly-iii-stack` 0.10.2, `oauth2-proxy`
  10.7.0) because the values here depend on chart internals — `fullnameOverride`
  in the `firefly-db` subchart, the map form of `extraArgs`. Bump them
  deliberately and re-check [values.yaml](values.yaml).
- **PostgreSQL is pinned to `16-alpine`**; the chart still defaults to
  `10-alpine`, EOL since 2022. Changing the major version after the first install
  needs a dump + restore, and 18+ would break the `subPath` data mount.
- **DB credentials live in a Secret**, created by the playbook and wired in via
  `firefly-db.configs.existingSecret`. Left alone, the chart puts the password in
  a plain ConfigMap and falls back to `POSTGRES_HOST_AUTH_METHOD=trust`, letting
  any pod that can reach `:5432` connect without one.
- A nightly `pg_dump` lands on the backup PVC (`0 3 * * *`), oldest dumps pruned
  past 80% usage, plus one on every `helm upgrade` and on uninstall. To restore,
  set `firefly-db.configs.RESTORE_ENABLED: true` in [values.yaml](values.yaml) —
  it renders a `post-install` hook that pipes `/var/lib/backup/firefly.sql` into
  `psql`.
- A `CronJob` hits `/api/v1/cron/<token>` daily for recurring transactions, bill
  reminders and auto-budgets. It curls the ClusterIP service directly, so it is
  unaffected by the SSO proxy.
- **Chart names are pinned** with `fullnameOverride` (`firefly`, `firefly-db`,
  `firefly-importer`) so the Services the middlewares point at stay predictable.
  Changing them means updating [templates/sso.yaml](templates/sso.yaml) too.
- No SMTP is configured. With SSO there are no password resets to mail, but if
  you want Firefly III notifications, add `MAIL_*` to `firefly-iii.config.env`
  using the repo's `SMTP_*` variables.
