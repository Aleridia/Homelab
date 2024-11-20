# Homelab setup

Little project to explain how I mounted my homelab and what is the configuration.
It's here to help new people and get some review about architecture or software choosen.

## Architecture
![Alt text](images/Network_archi.drawio.png?raw=true "Network architecture")

## Flux matrix

| VLANs       | 1 PC-local | 2 NAS | 3 Kubernetes | 4 Domotics |
| ----        | ----       | ----  | ----         | ----       |
| 1 PC-local  | ✅          | ✅     | ✅            | ✅          |
| 2 NAS       | ✅          | ✅     | ✅            | ❌          |
| 3 Kubernetes| ✅          | ✅     | ✅            | ❌          |
| 4 Domotics  | ✅          | ❌     | ❌            | ✅          |


## Ansible
`ansible-playbook -i inventory.yml playbook.yaml -K`
Enter the sudo password for the managed nodes