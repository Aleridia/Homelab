# Certificate issuer
This playbook installs two certificates issuer :
- Let's encrypt staging, aka `letsencrypt-staging`
- Let's encrypt prod, aka `letsencrypt-prod`

It uses DNS-01 challenge.\
The documentation used is [here](https://aureq.github.io/cert-manager-webhook-ovh/), and the helm chart [here](https://github.com/aureq/cert-manager-webhook-ovh/tree/main/charts/cert-manager-webhook-ovh).