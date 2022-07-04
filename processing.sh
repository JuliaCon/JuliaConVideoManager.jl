1   #!/bin/bash
  # INPUT:
  # A video as intro.mp4 in the same folder
  # A video as ARG1 in the same folder
  # OUTPUT:
  # A video with the same filename as ARG1 in procs/
  # Converts down to 720p
  ffmpeg -i intro.mp4 -i "$1"  -filter_complex \
   "[0:v]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:-1:-1,setsar=1,fps=30,format=yuv420p[v0];
   [1:v]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:-1:-1,setsar=1,fps=30,format=yuv420p[v1];
   [v0][0:a][v1][1:a]concat=n=2:v=1:a=1[v][a]" \
   -map "[    v]" -map "[a]" -c:v libx264 -c:a aac -movflags +faststart procs/"$1"
