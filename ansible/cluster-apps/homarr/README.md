# Homarr

## Keycloak configuration
Do not forget to create the client in the SSO with the following fields:
- Root url : https://homarr.<DOMAIN_NAME>
- Home url : /
- Valid redirect URIs : https://homarr.<DOMAIN_NAME>/api/auth/callback/oidc
- Web origins : https://homarr.<DOMAIN_NAME>
- Client authentication : On
- Authentication flow : Standard flow

Go to Clients -> select the homarr client -> Client scopes -> Add client scope -> "groups" and put "Default"
If groups does not exists, pleas refer to the [mealie readme](../mealie/README.md)

## Homarr configuration
Then when launching homarr, for admin group put "/<GROUP>" or "/<GROUP>/<SUBGROUP>" if you want to add a subgroup.