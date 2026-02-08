# Mealie

## Install
To install with ansible, simply run `ansible-playbook install.yaml`
Check the [official documentation](https://docs.mealie.io/documentation/getting-started/introduction/) for more information.

## Uninstall
/!\ Before uninstalling please backup the database manually in Mealie /!\

Run `ansible-playbook uninstall.yaml`

## Client creation in SSO
Do not forget to create the client in the SSO with the following fields:
- Root url : https://cuisine.<DOMAIN_NAME>
- Home url : /login*
- Valid redirect URIs : https://cuisine.<DOMAIN_NAME>/*
- Web origins : https://cuisine.<DOMAIN_NAME>
- Client authentication : On
- Authentication flow : Standard flow + Direct access grants

Then you need to make some ClientScope. Refer to the [Github discussion](https://github.com/mealie-recipes/mealie/discussions/3428).

## Compatibility with bring
To use Bring without internet input, I use [this project](https://github.com/felixschndr/mealie-bring-api).

Do not forget to follow instruction in the project's README to configure Mealie, with this address `http://mealie-bring-api/`.

## API
Due to exposition and [security issues](https://docs.mealie.io/documentation/getting-started/installation/security/), the mealie api is restricted.