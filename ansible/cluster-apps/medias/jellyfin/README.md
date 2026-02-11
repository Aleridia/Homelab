# Jellyfin
Uses this because plex is shit.

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