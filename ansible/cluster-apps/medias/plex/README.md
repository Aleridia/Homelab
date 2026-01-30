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

## Upgrading
When upgrading with Helm, some problems with pv/pvc can occur. To fix it :
1. Delete the pvc `k delete pvc nfs-plex -n <NAMESPACE>`
If the pvc don't want to be delete, patch it : `kubectl patch pvc nfs -p '{"metadata":{"finalizers":null}}' -n <NAMESPACE>`
2. Put the pv from `Retain` to `Available` : `k patch pv nfs -p '{"spec":{"claimRef": null}}' -n <NAMESPACE>`
3. Create the pvc `k apply -f pvc.yml`

## Configuration
### Network
- Do not forget to use the let's encrypt prod, else plex app wont work
- In the "Network" settings, add IP without auth like this : `192.168.X.1/255.255.255.0`
- Follow the [suggested plex configuration](https://trash-guides.info/Plex/Tips/Plex-media-server/)

### NFS configuration
To setup the NFS from the NAS sode, please follow [this post](https://forums.plex.tv/t/plex-1-43-0-10389-crashes/935115/12)

### Freeze during play
If the player freeze and had hard time to play, it's mostly due to the encoding.\
This happens when:
- ffmpeg / Jellyfin tries to scan the Matroska (MKV) index
- it reaches a very large EBML element near EOF
- the element violates strict EBML length expectations

Best format :
- MP4
- MKV
    - Video : H.264, AVC (x264)
    - Audio : AC3, EAC3, DTS (core)
    - WEB-DL
    - Groups : NTb, EVO, KiNGS
    - Subtitles : srt, add, ssa
AVI :
  - XviD, DivX, AC3/MP3 audio

Examples :
- WEB-DL x264 MULTi
- BluRay x264 MULTi (NO PGS)
- AVI MULTi
- WEB-DL x265 MULTi
- BluRay x265 MULTi (last resort)

Acceptable format :
-Only if WEB-DL : MKV x265

Avoid format :
- MKV : BluRay .x264, BlueRay .x265, MULTi TRUEFRENCH, PGS, HDMV, audio : DTS-HD MA (except for WEB-DL)

### FFMPEG
To re-encode a movie that have bad encoding, run this command : \
```
ffmpeg \
  -fflags +genpts \
  -err_detect ignore_err \
  -i "<MOVIE_TO_RE-ENCODE.mkv>" \
  -map 0 \
  -c copy \
  -avoid_negative_ts make_zero \
  "<OUTPUT_MOVIE.mkv>"
```