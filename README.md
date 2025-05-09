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
- x4 Dell optiplex 3060 i5 8500T 16go DDR4 2666mhz, m2 256go
- Minisforum MS-01-S1390 

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
- `sudo useradd -G sudo -m -s /bin/bash ansible`

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

And to use kubernetes collection :
- `ansible-galaxy collection install kubernetes.core`
- Load virtual env python `source <PATH_TO_ENV>/bin/activate`
- Install ansible-core `pip3 install ansible-core`
- Install dependencies : `pip3 install kubernetes pyyaml`
- Load the kubeffconfig file `export KUBECONFIG=<PATH_TO_PROJECT>/ansible/resources/kubeconfig.yaml`

Then run the playbook to harden machines :
`ansible-playbook -i inventory.yml hardening/hardening.yaml -K`
Enter the ansible user password for the managed nodes.

After this you need to add the private ssh key to authenticate to the nodes : `eval "$(ssh-agent -s)"` and add the key : `ssh-add <PATH_TO_PRIVATE_KEY>`.

Now install rke2 and Rancher in all the machines
`ansible-playbook -i inventory.yml rke2/install.yaml`

Note : you can uninstall rke2 & Rancher via the `rke2/uninstall.yaml` playbook.

## Load balancer

Current : configured a DNS server to redirect *.<DOMAIN> to a node. Usefull to manage ingress.

## Rancher
Optiplex-3060-1,2 & 3 are the server nodes.
Optiplex-3061-4 & minisfurom are the worker nodes.

Why 3 server nodes ?
- If I have only one and it crashes my cluster is fully down
- Number of server nodes need to be odd, because of the [quorum](https://medium.com/@osmarrod18/decoding-quorum-in-kubernetes-a-journey-of-learning-4e5de1d30e2d)

To configure rancher via UI, go to the `RANCHER_ADDRESS` and put the `BOOTSTRAP_PASSWORD`. 

## Storage
### Disks in nodes
I use longhorn to manage my SSD storage in the nodes and create automatically PV/PVC.
To install it, run the playbook in `cluster-apps/longhorn/install.yaml`.

### NFS
First you need to configure the NFS server. For synology follow [this guide](https://kb.synology.com/fr-fr/DSM/tutorial/How_to_access_files_on_Synology_NAS_within_the_local_network_NFS).

To **manually** mount the NFS on client, go to one node and add this line to the `/etc/fstab`
- `<SERVER_IP>:<PATH_TO_NFS> /media/NFS nfs vers=4.1,defaults,user,auto,_netdev,bg,rsize=16384,wsize=16384 0 0`
Then try to mount it and reload the daemonset :
- `mount -a`
- `systemctl daemon-reload`

If you want to let kube manage the NFS, make sure that all the nodes have `nfs-common` installed (already covered by rke2 install).

## Cluster-app

Here are all the helm repo dependencies that will be used :
- bitnami                 https://charts.bitnami.com/bitnami       
- codecentric             https://codecentric.github.io/helm-charts
- seafile                 https://300481.github.io/charts/

### Keycloak
This tool is used by all my other tool to be authenticated.

* To install launch the playbook `ansible-playbook cluster-apps/keycloak/install.yaml`
* Then you can go to the url `https://keycloak.<$DOMAIN_NAME>/auth`. Redirection won't work, will be patched later.

## Mariadb
For multiple tools I need mariadb instance.

* If previous installation, follow bitnami doc to change password, or delete PV.
* Set the $NAMESPACE var env to tell ansible where install mariadb `export NAMESPACE=<NAMESPACE>`
* Run the playbook to install it: `ansible-playbook cluster-apps/mariadb/install.yaml`
* To test if it works :
    - `kubectl run mariadb-client --rm --tty -i --restart='Never' --image  docker.io/bitnami/mariadb:11.4.4-debian-12-r2 --namespace default --command -- bash`
    - `mysql -h mariadb-<$NAMESPACE>.<$NAMESPACE>.svc.cluster.local -uroot -p <$MARIADB_DATABASE>` and then put root password


### Seafile
[Seafile](https://manual.seafile.com/latest/) is a file-hosting and sharing software.
[Github](https://github.com/300481/seafile-server) & [Helm](https://artifacthub.io/packages/helm/phybros-helm-charts/seafile) chart.

* Launch the playbook `ansible-playbook cluster-apps/seafile/install.yaml`
* Add `CSRF_TRUSTED_ORIGINS = ["https://seafile.<$DOMAIN_NAME>"]` to the /otp/seafile/conf/seahub_settings.py config file then delete pod. You need to modify it only once, it's persistent for all the next installation (unless you delete the seafile pv). [GH issue](https://github.com/haiwen/seafile/issues/2707).


## TODO
- [ ] Patch broken redirection (/ to /auth) in keycloak
- [ ] Harden cluster (rke2, keycloak FIPS, RBAC, PSA)
- [ ] Check if Cilium if worth it to add
- [ ] Add HAproxy
- [ ] Add webserver to host blog & auto deploy in medium + stackpills


## Sources
- To start homelab : https://github.com/veteranbv/Homelab-Blueprint
- Get more information about homelabs : https://www.reddit.com/r/homelab/
- Softwares : https://github.com/awesome-selfhosted/awesome-selfhosted
- Hardening playbooks : https://galaxy.ansible.com/ui/repo/published/devsec/hardening/
- Project that helped me to build my own homelab : https://github.com/nicogigi92/minilab
- Helm about installation process : https://ranchergovernment.com/blog/article-simple-rke2-longhorn-and-rancher-install