# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Infrastructure-as-code for a personal homelab: an Ansible-driven RKE2 (Rancher Kubernetes) cluster running on 5 mini-PC nodes plus a VPS reverse proxy, with self-hosted apps (Keycloak, Seafile, Mealie, Plex, Jellyfin, Immich, Vaultwarden, Minecraft, Homarr, Trek, etc.). There is no application source code — everything here is Ansible playbooks, Helm values, and Kubernetes manifests.

## Environment & secrets

All playbooks read configuration from environment variables via `lookup('env', ...)` — there are no Ansible vars files with secrets. Before running anything:

1. Copy `ansible/.env.sample` to `ansible/.env`, fill it in, then `source ansible/.env`.
2. For Kubernetes-touching playbooks, also `export KUBECONFIG=<repo>/ansible/resources/kubeconfig.yaml` and activate a Python venv with `kubernetes` + `pyyaml` installed.
3. SSH agent must hold the key referenced by `NODES_KEY` / `VPS_KEY` (`eval "$(ssh-agent -s)" && ssh-add <key>`).

`ansible/.env` is git-ignored. When adding a new variable to a playbook, also add it (empty) to `ansible/.env.sample` so the contract stays discoverable.

Required collections (install once):
- `ansible-galaxy collection install devsec.hardening`
- `ansible-galaxy collection install kubernetes.core`

## Inventory model

[ansible/inventory.yaml](ansible/inventory.yaml) defines logical groups, all hosts resolved from env vars:
- `first_server_node` — node_01, the bootstrap RKE2 server (kubeconfig is fetched from here, Rancher/cert-manager installed here)
- `server_nodes` — node_02, node_03 (additional control-plane; quorum = 3)
- `worker_nodes` — node_04, node_05 (RKE2 agents)
- `nodes` — all five above (used for cluster-wide add-ons like nfs-common)
- `vps` — external VPS hosting the nginx SNI reverse proxy + OpenVPN client; uses a non-default SSH port from `$SSH_PORT`

When writing a new playbook, target the smallest correct group rather than `nodes`. `first_server_node` is special-cased throughout (kubeconfig source, Rancher chart, single-run tasks).

## Standard ops

All commands run from `ansible/`:

```bash
# Hardening + fail2ban (run first on fresh nodes)
ansible-playbook -i inventory.yaml hardening/hardening.yaml -K

# RKE2 + Rancher + cert-manager + SMB CSI + Let's Encrypt issuer
ansible-playbook -i inventory.yaml rke2/install.yaml
ansible-playbook -i inventory.yaml rke2/uninstall.yaml

# Cluster apps — most expect $NAMESPACE to be exported
ansible-playbook cluster-apps/<app>/install.yaml
ansible-playbook cluster-apps/<app>/uninstall.yaml
```

Run a single play / task with `--tags <tag>` or `--start-at-task "<name>"`. Use `--check --diff` for dry runs. `-K` prompts for the sudo password used during hardening (the bootstrap `ansible` user has NOPASSWD sudo).

After SSH hardening, `ansible.cfg` sets `scp_if_ssh = True` because SFTP is disabled on hardened nodes — keep this flag.

## Architectural shape

**Ingress flow (post-Traefik migration, commit 5452f8a):**
1. Public DNS points `*.<DOMAIN_NAME>` at the VPS.
2. VPS nginx (configured by [ansible/cluster-apps/reverse-proxy/install.yaml](ansible/cluster-apps/reverse-proxy/install.yaml)) does HTTP→HTTPS redirect on :80 and SNI-passthrough TCP proxy on :443 via the `stream {}` block in [stream.d/k8s-sni.conf](ansible/cluster-apps/reverse-proxy/stream.d/k8s-sni.conf), targeting `$NODE_05`.
3. RKE2's built-in Traefik (configured via [resources/rke2-traefik-config.yaml](ansible/resources/rke2-traefik-config.yaml)) terminates TLS and handles Ingress objects. The chart enables `kubernetesIngressNginx` provider and the manifest declares an `IngressClass: nginx` with controller `k8s.io/ingress-nginx` so existing app manifests using `ingressClassName: nginx` and `nginx.ingress.kubernetes.io/*` annotations keep working unchanged. Do not rename the IngressClass — many app charts reference it.
4. The VPS also runs an OpenVPN client (`openvpn@client.service`) for outbound egress.

**RKE2 install sequencing** in [rke2/install.yaml](ansible/rke2/install.yaml):
- A localhost play templates `resources/rke2-config-{server,agent}.yaml` → `resources/config-*.yaml` by replacing `<TOKEN>`, `<RANCHER_ADDRESS>`, `<TLS-SAN>`. A second copy `config-server2.yaml` adds the `server:` join line for non-bootstrap servers.
- Server install is `throttle: 1` so node_01 fully starts before node_02/03 join — this matters for cluster bootstrap.
- The Traefik `HelmChartConfig` is dropped into `/var/lib/rancher/rke2/server/manifests/` **before** the rke2 install script runs, so the auto-deploy controller picks it up on first boot.
- A final localhost play deletes the generated `config-*.yaml` files; the canonical sources are the `rke2-config-*.yaml` templates.

**Cluster app convention** (e.g. [cluster-apps/keycloak/install.yaml](ansible/cluster-apps/keycloak/install.yaml)):
- Pull the OCI Helm chart into a `tempfile` directory, render `values.yaml` as a Jinja template into another tempfile, then `kubernetes.core.helm` install from the local path. Both tempfiles are removed in an `always:` block.
- Most apps use `$NAMESPACE` as both the release name and namespace (`create_namespace: true`).
- App-specific READMEs (e.g. [keycloak/README.md](ansible/cluster-apps/keycloak/README.md), [seafile/README.md](ansible/cluster-apps/seafile/README.md)) document post-install manual steps — read them before declaring an install "done".

**Auth:** Keycloak is the central IdP; most apps integrate via OIDC (`<APP>_CLIENT_ID` / `<APP>_CLIENT_SECRET` env vars). When adding a new app, follow the existing OIDC client pattern rather than per-app auth.

**Storage:** Longhorn for SSD-backed PVCs ([cluster-apps/longhorn](ansible/cluster-apps/longhorn/)); NFS from the Synology NAS for media/bulk (mounted via `/etc/fstab` on nodes); SMB CSI driver is installed during RKE2 setup.

**Certificates:** cert-manager + Let's Encrypt issuer installed by `rke2/cert-issuer/install.yaml` (imported at the end of `rke2/install.yaml`). When adding an Ingress, follow the pattern in [ansible/rke2/README.md](ansible/rke2/README.md): start with `letsencrypt-staging`, switch to `letsencrypt-prod` only after success to avoid rate-limit bans.

## Editing conventions

- Keep playbook tasks idempotent — most use `ansible.builtin.{copy,replace,lineinfile,blockinfile,systemd_service}` with explicit state. `shell:` is only used for one-shots that aren't naturally idempotent (helm pull, install scripts).
- Placeholder substitution in config files uses `<UPPER_CASE>` tokens replaced via `ansible.builtin.replace` (see reverse-proxy and rke2 plays). Match this style when adding new templated configs.
- Hardening play uses the `devsec.hardening` collection — its `sysctl_overwrite` block deliberately relaxes `rp_filter` and `accept_redirects` because SMB/NFS traffic breaks under the defaults. Don't tighten these without re-validating NFS mounts.
