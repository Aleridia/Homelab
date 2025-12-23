# Minecraft server
Source for chart : `https://github.com/itzg/minecraft-server-charts`

Inspired from (docker minecraft)[https://github.com/itzg/docker-minecraft-server].
So the (documentation)[https://docker-minecraft-server.readthedocs.io/en/latest/] is the same for both.

To install it :
- Deploy PV/PVC :
    - `ensubst < pv.yml | k apply -f -`
    - `k apply -f pvc.yml`
- `helm repo add itzg https://itzg.github.io/minecraft-server-charts/`
- `helm install --namespace minecraft --create-namespace minecraft -f values.yaml --set minecraftServer.autoCurseForge.apiKey.key=$CURSEFORGE_API_KEY itzg/minecraft`