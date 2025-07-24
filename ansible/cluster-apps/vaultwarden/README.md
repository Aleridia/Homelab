# Vaultwarden

## Install
To install with ansible, simply run `ansible-playbook install.yaml`
Check the [official documentation](https://github.com/dani-garcia/vaultwarden/wiki) for more information.

## Uninstall
Run `ansible-playbook uninstall.yaml`

## Hardening
- To generate the admin token : `echo -n "<PASSWORD>" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4`. Then you can access the admin panel to this address : `vaultwarden.<DOMAINE_NAME>/admin`
- All the hardening in the [wiki](https://github.com/dani-garcia/vaultwarden/wiki/Hardening-Guide) is applied.

## SMTP
I use SMTP server to send mail for activation and forgot password.
You have good free SMTP server [here](https://github.com/dani-garcia/vaultwarden/wiki/SMTP-Configuration#smtp-servers).