# Homelab setup

Little project to explain how I mounted my homelab and what is the configuration.
It's here to help new people and get some review about architecture or software choosen.

## Hardware
- Nas : DS218+, 17.2W, 2x 3.6TO RAID 1
- UDM pro : 33W
- Switch Tenda SG108
- Tenda PoE Injector 48V, IEEE802.3at
- Wifi : Ubiquiti U6 Long-Range
- Raspberry pi 4
- Ubiquiti U6-LR
- x4 Dell optiplex 3060 i5 8500T 8go DDR4 2666mhz, m2 256go

## Architecture
![Alt text](images/Network_archi.drawio.png?raw=true "Network architecture")

## Flux matrix

| VLANs       | 1 PC-local | 2 NAS | 3 Kubernetes    | 4 Domotics  |
| ----        | ----       | ----  | ----            | ----        |
| 1 PC-local  | ✅          | ✅     | ✅            | ✅          |
| 2 NAS       | ✅          | ✅     | ✅            | ❌          |
| 3 Kubernetes| ✅          | ✅     | ✅            | ❌          |
| 4 Domotics  | ✅          | ❌     | ❌            | ✅          |


## Ansible
Before start you need to create an user for ansible in all machines with sudoers rights without password :
`sudo visudo` and add this at end of file: 
```
#Allow ansible to sudo without password
<USER> ALL=(ALL) NOPASSWD: ALL
```
Then source the var env : `source .env`.

It's a bad thing for security, but we need this to harden our machines.
If you want to be full safe you can still delete this user after the playbook.

You have to download ansible hardening devsec playbook :
`ansible-galaxy collection install devsec.hardening`


Then run the playbook to harden machines :
`ansible-playbook -i inventory.yml hardening/hardening.yaml -K`
Enter the ansible user password for the managed nodes.

After this you need to add the private ssh key to authenticate to the nodes : `eval "$(ssh-agent -s)"` and add the key : `ssh-add <PATH_TO_PRIVATE_KEY>`.

Now install rke2 and Rancher in all the machines
`ansible-playbook -i inventory.yml rke2/install.yaml -K`

Note : you can uninstall rke2 & Rancher via the `rke2/uninstall.yaml` playbook.

## Load balancer
TODO : Add HAproxy

Current : configured a DNS server to redirect *.<DOMAIN> to a node. Usefull to manage ingress.

## Rancher
Optiplex-3060-1,2 & 3 are the server nodes.
Optiplex-3061-4 is the single worker node.

Why 3 server nodes ?
- If I have only one and it crashes my cluster is fully down
- Number of server nodes need to be odd, because of the [quorum](https://medium.com/@osmarrod18/decoding-quorum-in-kubernetes-a-journey-of-learning-4e5de1d30e2d)

To configure rancher via UI, go to the `RANCHER_ADDRESS` and put the `BOOTSTRAP_PASSWORD`. 

I use longhorn to manage my SSD storage in the nodes and create automatically PV/PVC.
To install it, run the playbook in `cluster-apps/longhorn.yaml`.

## Cluster-app

### Keycloak
Used to have SSO.
In progress.

## Mariadb
For multiple tools I need mariadb instance.

* If previous installation, follow bitnami doc to change password, or delete PV.
* Deploy the secret with credentials :
    - Use envsubst to inject var env : `envsubst < mariadb-secret-template.yaml > secret.yaml`
    - Deploy the secret in the namespace : `kubectl apply -f secret.yaml -n <NAMESPACE>`
* `helm install mariadb oci://registry-1.docker.io/bitnamicharts/mariadb -f mariadb/values.yaml --set auth.username=$MARIADB_USERNAME --set auth.database=$MARIADB_DATABASE`
* To test if it works :
    - `kubectl run mariadb-client --rm --tty -i --restart='Never' --image  docker.io/bitnami/mariadb:11.4.4-debian-12-r2 --namespace default --command -- bash`
    - `mysql -h mariadb.default.svc.cluster.local -uroot -p <DATABASE_NAME>` and then put root password

TODO : configure custom resources for mariadb

### Seafile
[Seafile](https://manual.seafile.com/latest/) is a file-hosting and sharing software.
[Github](https://github.com/300481/seafile-server) & [Helm](https://artifacthub.io/packages/helm/phybros-helm-charts/seafile) chart.

* Create specific namespace for it `kubectl create namespace seafile`
* Follow [Mariadb](#mariadb) steps to install the db in the namespace
* `helm repo add phybros-helm-charts https://phybros.github.io/helm-charts`


## TODO

- [ ] Check if Cilium if worth it to add
- [ ] Use NAS as storage
- [ ] Enhance documentation
- [ ] Add webserver to host blog & auto deploy in medium + stackpills

## Sources
- To start homelab : https://github.com/veteranbv/Homelab-Blueprint
- Get more information about homelabs : https://www.reddit.com/r/homelab/
- Softwares : https://github.com/awesome-selfhosted/awesome-selfhosted
- Hardening playbooks : https://galaxy.ansible.com/ui/repo/published/devsec/hardening/
- Project that helped me to build my own homelab : https://github.com/nicogigi92/minilab
- Helm about installation process : https://ranchergovernment.com/blog/article-simple-rke2-longhorn-and-rancher-install