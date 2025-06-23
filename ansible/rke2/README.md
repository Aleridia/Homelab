# RKE2

## Upgrade
Upgrades are automatics, following the [documentation](https://docs.rke2.io/upgrades/automated_upgrade) to install it.
Change the version of rke2 in files then apply with `k apply -f upgrade-<FILE>.yaml`.

## Certificates
The issuer installation is done automatically with the `install.yaml`.
If you want to do it manually then you must apply the `certificates/issuer.yaml` to the cluster.

After this, to create a certificate :
1. Use the `certificates/ingress-tls-example.yaml` and try to deploy with the `letsencrypt-staging` for the `cert-manager.io/cluster-issuer:`
3. When it works, you can switch to `letsencrypt-prod`. If you spam a lot in the prod, let's encrypt can ban the IP, so be careful
4. Then deploy app. In some charts you don't need to deploy manually the tls certificate, giving it the issuer works (e.g. plex)
5. Don't forget to redirect port in the router

Source : https://help.ovhcloud.com/csm/en-public-cloud-kubernetes-secure-nginx-ingress-cert-manager?id=kb_article_view&sysparm_article=KB0049952

To generate a certificate :
https://ongkhaiwei.medium.com/generate-lets-encrypt-certificate-with-dns-challenge-and-namecheap-e5999a040708