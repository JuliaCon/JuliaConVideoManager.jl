using FFMPEG
using JSON

@assert length(ARGS) == 2
const preroll = ARGS[1]
const file = ARGS[2]

# 1. Query properties of file

json = join(FFMPEG.exe(`-v error -show_entries stream=width,height,r_frame_rate -of json $(file)`, command=FFMPEG.ffprobe, collect=true), "\n")
properties = JSON.Parser.parse(json)
streams = properties["streams"]

filter!(i -> !isempty(i) && get(i, "r_frame_rate", "0/0") != "0/0", streams)
metadata = map(stream -> (stream["width"], stream["height"], stream["r_frame_rate"]), streams)

unique!(metadata)
width, height, fps = only(metadata)

args = ```
-i $(preroll)
-i $(file)
-filter_complex 
"[0:v]scale=$(width):$(height):force_original_aspect_ratio=decrease,pad=$(width):$(height):-1:-1,setsar=1,fps=$fps,format=yuv420p[v0]; \
 [1:v]setsar=1,fps=$fps,format=yuv420p[v1];
  [v0][0:a][v1][1:a]concat=n=2:v=1:a=1[v][a]"
-map "[v]"
-map "[a]"
-c:v libx264
-preset slow
-crf 18
-c:a aac
-b:a 192k
-movflags +faststart
out/$(file)
```

@show args
FFMPEG.exe(args)

