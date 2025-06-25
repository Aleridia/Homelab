# Keycloak

## Deploy
To deploy it automatically use `ansible-playbook install.yaml`

Else use `helm upgrade --install --create-namespace keycloak -f values.yaml oci://registry-1.docker.io/bitnamicharts/keycloak` and replace ansible fields in the values.yaml.

## Configuration
### Config map header
I use a config map to make nginx pass the headers.
The source used : https://dev.to/aws-builders/keycloak-with-nginx-ingress-6fo

### For production
All the recommandation in the [keycloak documentation](https://www.keycloak.org/server/configuration-production) have been followed for a production use.

## Realms
- If you got a 403 error to access the "Manage account" : Client -> Account -> Web origins to "*". Make this for "account-console" too. [Source](https://github.com/keycloak/keycloak/issues/34780)