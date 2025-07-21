# Mealie

## Install
To install with ansible, simply run `ansible-playbook install.yaml`
Check the [official documentation](https://docs.mealie.io/documentation/getting-started/introduction/) for more information.

## Uninstall
/!\ Before uninstalling please backup the database manually in Mealie /!\

Run `ansible-playbook uninstall.yaml`

## Client creation in SSO
Do not forget to create the client in the SSO with the following fields:
- Root url : https://mealie.<DOMAIN_NAME>
- Home url : /login*
- Valid redirect URIs : https://mealie.<DOMAIN_NAME>/*
- Web origins : https://mealie.<DOMAIN_NAME>
- Client authentication : On

## Compatibility with bring
https://github.com/felixschndr/mealie-bring-api