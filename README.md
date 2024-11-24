# Homelab setup

Little project to explain how I mounted my homelab and what is the configuration.
It's here to help new people and get some review about architecture or software choosen.

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
`sudo visudo` and add this : 
```
#Allow ansible to sudo without password
<USER> ALL=(ALL) NOPASSWD: ALL
```

It's a bad thing for security, but we need this to harden our machines.
If you want to be full safe you can still delete this user after the playbook.

You have to download ansible hardening devsec playbook :
`ansible-galaxy collection install devsec.hardening`


Then run the playbook :
`ansible-playbook -i inventory.yml playbook.yaml -K`
Enter the ansible user password for the managed nodes.

## Hardware
- Nas : DS218+, 17.2W, 2x 3.6TO RAID 1
- UDM pro : 33W
- Raspberry pi 4
- Ubiquiti U6-LR
- x4 Dell optiplex 3060 i5 8500T 8go DDR4 2666mhz, m2 256go


## Sources
- To start homelab : https://github.com/veteranbv/Homelab-Blueprint
- Get more information abotu homelabs : https://www.reddit.com/r/homelab/
- Softwares : https://github.com/awesome-selfhosted/awesome-selfhosted
- Hardening playbooks : https://galaxy.ansible.com/ui/repo/published/devsec/hardening/