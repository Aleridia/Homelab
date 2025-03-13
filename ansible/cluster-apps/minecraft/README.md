# Minecraft server
Source for chart : `https://github.com/itzg/minecraft-server-charts`

Inspired from (docker minecraft)[https://github.com/itzg/docker-minecraft-server].
So the (documentation)[https://docker-minecraft-server.readthedocs.io/en/latest/] is the same for both.

To install it :
- `helm repo add itzg https://itzg.github.io/minecraft-server-charts/`
- `helm install --namespace ingress-nginx --create-namespace --name minecraft -f values.yaml itzg/minecraft`