# TREK

[TREK](https://github.com/mauriceboe/TREK) is a self-hosted travel planner.

## Install
To install with ansible, simply run `ansible-playbook install.yaml`.
Check the [official documentation](https://github.com/mauriceboe/TREK) for more information.

## Uninstall
Run `ansible-playbook uninstall.yaml`.

The persistent volumes (`data` and `uploads`) are kept by Kubernetes after the
release is removed. Delete the PVCs manually if you want to wipe the data.

## Environment variables
The playbook reads the following variables from the environment:

| Variable | Purpose |
| --- | --- |
| `NAMESPACE` | Kubernetes namespace to install into. |
| `DOMAIN_NAME` | Base domain (e.g. `<DOMAIN_NAME>`) used to build the Keycloak issuer URL. |
| `REALM_NAME` | Keycloak realm hosting the trek client. |
| `TREK_CLIENT_ID` | OIDC client ID registered in Keycloak. |
| `TREK_CLIENT_SECRET` | OIDC client secret. |
| `TREK_TLS_SECRET` | Name of the Kubernetes secret cert-manager will populate. |
| `KEYCLOAK_HOME_GROUP` | Group whose members get admin rights inside TREK. |

## Client creation in SSO
Create a client in Keycloak with the following fields:
- Root URL: `https://trek.<DOMAIN_NAME>`
- Home URL: `/`
- Valid redirect URIs: `https://trek.<DOMAIN_NAME>/*`
- Web origins: `https://trek.<DOMAIN_NAME>`
- Client authentication: On
- Authentication flow: Standard flow

Make sure the client exposes the `groups` scope so `OIDC_ADMIN_CLAIM=groups`
can resolve. On a fresh install, the first user that logs in via SSO becomes
admin automatically.

## Notes
- The chart is pulled from the upstream git repo
  (`https://github.com/mauriceboe/TREK`) under `charts/trek`.
- `generateEncryptionKey: true` lets the chart generate the at-rest
  `ENCRYPTION_KEY` once and reuse it across upgrades — do not change it after
  the first install or stored secrets become unreadable.
- `ALLOW_INTERNAL_NETWORK` is enabled so TREK can reach Immich (and other
  internal services) on RFC-1918 addresses.
