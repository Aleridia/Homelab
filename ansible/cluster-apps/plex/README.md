# Plex
## Install
First create the plex namespace and the pv/pvc for the NFS :
- `kubectl create namespace plex`
- `kubectl apply -f pv.yml`
- `kubectl apply -f pvc.yml`

Taking plex from [this repo](https://github.com/plexinc/pms-docker/tree/master/charts/plex-media-server).
More infos can be found in thei [blog](https://www.plex.tv/blog/plex-pro-week-23-a-z-on-k8s-for-plex-media-server/).

- `helm repo add plex https://raw.githubusercontent.com/plexinc/pms-docker/gh-pages`
- `helm upgrade --namespace plex --create-namespace --install plex plex/plex-media-server --values values.yaml`

## Config
To claim the Plex server, you will need to forward port :
- `kubectl port-forward <POD_NAME> 32400:32400 -n plex`

Then go in browser to this address `http://127.0.0.1:32400/web`.