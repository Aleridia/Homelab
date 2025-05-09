# Plex

## Ansible install
Before launching the playbook, configure the python virutal_env. Cf the global [README](../../../README.md#ansible). 

* To install launch the playbook `ansible-playbook cluster-apps/plex/install.yml`
* Then you can go to the url `https://plex.<$DOMAIN_NAME>`. 

## Manual install
First create the plex namespace and the pv/pvc for the NFS :
- `kubectl create namespace plex`
- `kubectl apply -f pv.yml`
- `kubectl apply -f pvc.yml`

Taking plex from [this repo](https://github.com/plexinc/pms-docker/tree/master/charts/plex-media-server).
More infos can be found in this [blog](https://www.plex.tv/blog/plex-pro-week-23-a-z-on-k8s-for-plex-media-server/).

- `helm repo add plex https://raw.githubusercontent.com/plexinc/pms-docker/gh-pages`
- `helm upgrade --namespace plex --create-namespace --install plex plex/plex-media-server --values values.yaml`

## Config
To claim the Plex server, you will need to forward port :
- `kubectl port-forward <POD_NAME> 32400:32400 -n <$NAMESPACE>`

Then go in browser to this address `http://127.0.0.1:32400/web`.