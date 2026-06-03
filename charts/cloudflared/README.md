# Cloudflare edge for a Traefik cluster — tunnel + auto-TLS

Reusable, app-agnostic cluster infrastructure to expose in-cluster HTTP services to
the internet through Cloudflare **without opening any inbound port**, with TLS certs
that **auto-rotate** via cert-manager. Drop this `deploy/` folder into any cluster
that runs Traefik + cert-manager; it carries no application-specific config.

```
browser → Cloudflare edge → (outbound tunnel) → cloudflared → Traefik → your Service
```

Two independent pieces, each in its own subfolder:

| Folder                                   | What it is                                                                        | Scope                                               |
| ---------------------------------------- | --------------------------------------------------------------------------------- | --------------------------------------------------- |
| [`origin-ca-issuer/`](origin-ca-issuer/) | cert-manager issuer that signs **Cloudflare Origin CA** certs (no ACME challenge) | cluster-wide controller + one `ClusterOriginIssuer` |
| [`cloudflared/`](cloudflared/)           | the **Cloudflare Tunnel** daemon — the only thing reachable from outside          | one Deployment in the `cloudflare` namespace        |

You can install either on its own, but together they give you "publish a hostname →
get a cluster with valid TLS and no open ports."

---

## Prerequisites

- **Traefik** as the ingress controller (RKE2/K3s ship it; Service is usually
  `rke2-traefik` / `traefik` in `kube-system`).
- **cert-manager** already installed.
- A domain whose DNS is managed by **Cloudflare** (a zone in your account).
- `cloudflared` CLI locally, logged in (`cloudflared tunnel login`).

---

## Step 0 — Find your Traefik names (do this first)

These names appear in three places that must agree; a mismatch silently breaks
ingress and is the **#1 thing that goes wrong**.

```bash
kubectl -n kube-system get svc  | grep -i traefik          # the SERVICE name
kubectl -n kube-system get pods --show-labels | grep -i traefik   # the pod LABELS
```

- **Service name** → `cloudflared/10-config.yaml` (`service: https://<name>.kube-system…`).
- **A pod label identifying Traefik** (e.g. `app.kubernetes.io/name=rke2-traefik`) →
  `cloudflared/30-networkpolicy.yaml` (the Traefik egress peer), and on each app's
  side, whatever NetworkPolicy lets Traefik reach it.

---

## Part A — Auto-rotating TLS (Cloudflare Origin CA)

cert-manager drives issuance + renewal; the issuer is Cloudflare's
[`origin-ca-issuer`](https://github.com/cloudflare/origin-ca-issuer). Issuance is a
direct API call (no DNS-01/HTTP-01 challenge). Origin CA certs are trusted by
Cloudflare's edge, not the public — which is exactly right here: the public
browser→edge leg uses Cloudflare's own edge cert, and Traefik only presents this
cert to `cloudflared` over the in-cluster hop.

### A1 — Install the CRDs + controller (once per cluster)

```bash
VERSION="v0.14.2"
kubectl apply -f https://raw.githubusercontent.com/cloudflare/origin-ca-issuer/${VERSION}/deploy/crds/cert-manager.k8s.cloudflare.com_originissuers.yaml
kubectl apply -f https://raw.githubusercontent.com/cloudflare/origin-ca-issuer/${VERSION}/deploy/crds/cert-manager.k8s.cloudflare.com_clusteroriginissuers.yaml

# Controller (OCI chart). Check the latest chart version first:
#   helm show chart oci://ghcr.io/cloudflare/origin-ca-issuer-charts/origin-ca-issuer
helm install origin-ca-issuer \
  oci://ghcr.io/cloudflare/origin-ca-issuer-charts/origin-ca-issuer \
  --version 0.6.8 -n origin-ca-issuer --create-namespace
```

### A2 — Cloudflare API token → Secret

Cloudflare dashboard → **My Profile → API Tokens → Create Custom Token**, permission:

```
Zone · SSL and Certificates · Edit      (scoped to your zone)
```

The token lives in the **controller's** namespace (`origin-ca-issuer`) — a
`ClusterOriginIssuer` resolves it from there. See
[`origin-ca-issuer/secret.example.yaml`](origin-ca-issuer/secret.example.yaml) (a
template — don't apply it with the placeholder). Quickest path:

```bash
kubectl -n origin-ca-issuer create secret generic cloudflare-origin-ca-token \
  --from-literal=key=<CLOUDFLARE_API_TOKEN>
```

### A3 — Create the ClusterOriginIssuer

```bash
kubectl apply -f origin-ca-issuer/clusteroriginissuer.yaml
kubectl describe clusteroriginissuer origin-ca-issuer   # Status: True, Type: Ready
```

That's it — **one** issuer now serves every namespace.

---

## Part B — Cloudflare Tunnel (`cloudflared`)

A locally-managed tunnel: the public allowlist lives in git
([`cloudflared/10-config.yaml`](cloudflared/10-config.yaml)), not the dashboard.

Login to cloudflared:
```bash
cloudflared tunnel login
```

### B1 — Create the tunnel + credentials Secret

```bash
cloudflared tunnel create <name>            # prints a UUID and writes ~/.cloudflared/<UUID>.json

kubectl apply -f cloudflared/00-namespace.yaml
kubectl -n cloudflare create secret generic tunnel-credentials \
  --from-file=credentials.json="$HOME/.cloudflared/<UUID>.json"
```

### B2 — Fill in the config

In `cloudflared/10-config.yaml`:

- set `tunnel:` to the **UUID** from B1,
- replace the `app.example.com` example block with your real hostname(s) — **one
  block per app**, all sharing this single tunnel,
- confirm the Traefik `service:` name from Step 0.

### B3 — Deploy + create the public DNS records

```bash
kubectl apply -f cloudflared/                         # config, deployment, networkpolicy
cloudflared tunnel route dns <name> app.example.com   # proxied CNAME; repeat per hostname
```

In the Cloudflare dashboard: **SSL/TLS → Overview →** set mode to **Full (strict)**.

---

## Connecting an application to this edge

The infra above is generic; an app opts in with two small things:

1. **TLS** — annotate its Ingress so cert-manager's ingress-shim issues a cert from
   the shared issuer (cert auto-created into the Ingress `tls.secretName`):

   ```yaml
   metadata:
     annotations:
       cert-manager.io/issuer: origin-ca-issuer
       cert-manager.io/issuer-kind: ClusterOriginIssuer
       cert-manager.io/issuer-group: cert-manager.k8s.cloudflare.com
   ```

   (Nothing to create in the app's namespace — the issuer and its token are global.)

2. **Public route** — add one `hostname:` block for it in `cloudflared/10-config.yaml`
   and run `cloudflared tunnel route dns <name> <hostname>`.

3. **NetworkPolicy** (if the app default-denies ingress) — allow the Traefik pod
   (Step 0 labels) to reach it.
---

## Verify

```bash
kubectl -n cloudflare rollout status deploy/cloudflared
kubectl -n cloudflare logs -l app.kubernetes.io/name=cloudflared --tail=50
#   → look for "Registered tunnel connection" (≈4 connections)

curl -I https://app.example.com/      # expect HTTP/2 200 (or your app's status)
```

Troubleshooting:

- **502 / 523** → cloudflared can't reach Traefik. Recheck the `service:` name
  (Step 0) and the app's NetworkPolicy controller label.
- **404 from cloudflared** → request host doesn't match a `hostname:` in
  `10-config.yaml`.
- **Cert stuck NotReady** → `kubectl describe certificate <name>`; check the token
  Secret is in `origin-ca-issuer` and the `ClusterOriginIssuer` is `READY=True`.

---

## How it stays locked down

- **No inbound port.** cloudflared dials _out_ to Cloudflare; nothing listens
  publicly. Only hostnames in `10-config.yaml` are routable — everything else hits
  the `http_status:404` catch-all.
- **cloudflared egress is pinned** (`cloudflared/30-networkpolicy.yaml`): CoreDNS,
  the Traefik pod, and the Cloudflare edge (7844/443) only — cluster/LAN/metadata
  ranges excluded.
- Both workloads run **hardened**: non-root, read-only root FS, all caps dropped,
  `RuntimeDefault` seccomp, no API-token mount; the `cloudflare` namespace enforces
  the PSA `restricted` profile.
- The token Secret's blast radius is one namespace (`origin-ca-issuer`); the API
  token is scoped to a single Cloudflare zone with only SSL-cert edit rights.
- Optional: layer **Cloudflare Access** (Zero Trust) on a hostname for edge auth.

## TODO before production

- Pin the `cloudflared` image tag in `cloudflared/20-deployment.yaml` (currently
  `:latest`) — see https://github.com/cloudflare/cloudflared/releases.
- Optionally validate the cloudflared→Traefik hop (drop `noTLSVerify`, mount the
  Cloudflare Origin CA root, set `caPool`).
