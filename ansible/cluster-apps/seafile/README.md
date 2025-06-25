# Seafile

## Install
To install with ansible, simply run `ansible-playbook install.yaml`
To install manually :
1. Pull [this repo](https://github.com/Aleridia/seafile-helm-chart), or directly [this](https://github.com/haiwen/seafile-helm-chart) if the [PR](https://github.com/haiwen/seafile-helm-chart/pull/12/files) have been accepted.
2. Then run `helm upgrade --install seafile -f values.yaml <SEAFILE_REPO>` with the values in this folder

Check the [official documentation](https://manual.seafile.com/12.0/setup/helm_chart_single_node/) for more information.

## Configure SSO
Firstly you need a running Keycloak instance.
You will need to put the followings lines in the `/otp/seafile/conf/seahub_settings.py` file. To do this, run a console directly in the seafile pod. Then you can delete the pod, it will be rebuild with the new configuration.

/!\ Do not forget to replace fields /!\

```
#Start SSO
ENABLE_OAUTH = True
OAUTH_CREATE_UNKNOWN_USER = True
OAUTH_ACTIVATE_USER_AFTER_CREATION = True
OAUTH_CLIENT_ID = "<CLIENT_ID_IN_KEYCLOAK>"
OAUTH_CLIENT_SECRET = "<CLIENT_SECRET_IN_KEYCLOAK>"
OAUTH_REDIRECT_URL = "https://<SEAFILE_ADDRESS>/oauth/callback/"

OAUTH_PROVIDER_DOMAIN = '<SEAFILE_ADDRESS>'
OAUTH_AUTHORIZATION_URL = 'https://<KEYCLOAK_ADDRESS>/realms/<KEYCLOAK_REALM>/protocol/openid-connect/auth'
OAUTH_TOKEN_URL = 'https://<KEYCLOAK_ADDRESS>/realms/<KEYCLOAK_REALM>/protocol/openid-connect/token'
OAUTH_USER_INFO_URL = 'https://<KEYCLOAK_ADDRESS>/realms/<KEYCLOAK_REALM>/protocol/openid-connect/userinfo'

OAUTH_SCOPE = ["openid", "profile", "email"]
OAUTH_ATTRIBUTE_MAP = {
    "sub": (True, "uid"),
    "email": (False, "contact_email"),
    "name": (False, "name")
}
```

Source : https://forum.seafile.com/t/setting-up-keycloak-for-sso/22520

## Thing to know
- If you got this message `2025-06-24 13:38:01 This is an idle script (infinite loop) to keep container running.` it's probably a DB problem. So try to delete and then reinstall the database before reinstalling Seafile. This occur generally if you want to install a new Seafile chart withtout upgrading
- If you got this error `Sorry, but the requested page is unavailable due to a server hiccup.` it's because of a bad login/password
- If you got an error while uploading a file in Firefox with linux : don't worry it works with phone or on windows