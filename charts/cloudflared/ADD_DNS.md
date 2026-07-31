To add a new DNS entry :
1. Get the current configmap
# Save it to the file you opened (strips runtime metadata so it re-applies cleanly)
kubectl -n cloudflare get configmap cloudflared-config -o yaml \
  --show-managed-fields=false > tmp.yaml

2. Add the new "hostname"
3. Apply and reload `kubectl apply -f tmp.yaml && kubectl -n cloudflare rollout restart deploy/cloudflared` 
4. Create the DNS `cloudflared tunnel route dns <tunnel-name> app2.example.com`