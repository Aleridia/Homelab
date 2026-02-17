# Reverse proxy
Setting up a reverse proxy for the VPS to redirect some services.

## Ansible
To install it with ansible, run `ansible-playbook install.yaml -i ../../inventory.yaml

## Files to modify
- VPN file, to avoid network interface problems
    - Comment `redirect-gateway def1`
    - Add `pull-filter ignore "redirect-gateway"`

## To host static websites in the VPS
```bash
#Create the folder
sudo mkdir -p /var/www/<NAME>
#Copy the static sources to the www folder
sudo rsync -av --delete <SOURCE_STATIC> /var/www/<NAME>/
sudo find /var/www/<NAME> -type d -exec chmod 755 {} \;
sudo find /var/www/<NAME> -type f -exec chmod 644 {} \;
sudo chown -R www-data:www-data /var/www/<NAME>
```

### Configure HTTPS
1. Create the certificates by following [Generate HTTPS certificates](#generate-https-certificates)
2. Create conf file named `<NAME>`. \
Be careful to the `ssl_certificate` and `ssl_certificate_key` path, if you tested with staging you will have multiple folders (one folder for one cert generated). \
So take care of the certbot output and put the `Certificate is saved at:` & `Key is saved at:` in the `template/static.conf` file.

```bash
sudo mv <NAME> /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/<NAME> /etc/nginx/sites-enabled/
sudo nginx -t && systemctl reload nginx
```

## Generate HTTPS certificates
1. Follow [this](https://aureq.github.io/cert-manager-webhook-ovh/#ovh-api-keys) tutorial to get application_key, application_secret and consumer_key
2. Create a file named `ovh.ini`. It will be used later :
```
dns_ovh_endpoint = ovh-eu
dns_ovh_application_key = YOUR_APP_KEY
dns_ovh_application_secret = YOUR_APP_SECRET
dns_ovh_consumer_key = YOUR_CONSUMER_KEY
```

```bash
sudo apt install certbot python3-certbot-nginx python3-certbot-dns-ovh -y
sudo mkdir -p /etc/letsencrypt
#This file you previously created
sudo mv ovh.ini /etc/letsencrypt/ovh.ini
sudo chmod 600 /etc/letsencrypt/ovh.ini
#Staging : only to test if it's working. Then apply prod
sudo certbot certonly --dns-ovh --dns-ovh-credentials /etc/letsencrypt/ovh.ini --server https://acme-staging-v02.api.letsencrypt.org/directory -d <NAME>.<DOMAIN_NAME>
#Prod : only when staging is good (certificate created)
sudo certbot certonly --dns-ovh --dns-ovh-credentials /etc/letsencrypt/ovh.ini --dns-ovh-propagation-seconds 60 -d <NAME>.<DOMAIN_NAME>
```
After the certbot command, you will have a new DNS entry created, named `_acme-challenge.<NAME>.<DOMAIN_NAME>.`.

## Debug helper
If you got a stream that listen on 443, add this configuration in the stream `/etc/nginx/stream.d/<NAME>.conf` :
```nginx
map $ssl_preread_server_name $selected_upstream {
    ...
    default             web;
}
upstream web {
    server 127.0.0.1:8443;
}
server {
    listen 443;
    proxy_pass $selected_upstream;
    ssl_preread on;
}
```
