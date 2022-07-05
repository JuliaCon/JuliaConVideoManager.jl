using FFMPEG
using JSON

@assert length(ARGS) == 2
const preroll = ARGS[1]
const file = ARGS[2]

# 1. Query properties of file

json = join(FFMPEG.exe(`-v error -show_entries stream=width,height -of json $(file)`, command=FFMPEG.ffprobe, collect=true), "\n")
properties = JSON.Parser.parse(json)
streams = properties["streams"]

filter!(!isempty, streams)
sizes = map(stream -> (stream["width"], stream["height"]), streams)

unique!(sizes)
width, height = only(sizes)

args = ```
-i $(preroll)
-i $(file)
-filter_complex 
"[0:v]scale=$(width):$(height):force_original_aspect_ratio=decrease,pad=$(width):$(height):-1:-1,setsar=1,fps=30,format=yuv420p[v0]; \
 [1:v]setsar=1,fps=30,format=yuv420p[v1];
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

