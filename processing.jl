using FFMPEG
using JSON

@assert length(ARGS) == 2
const preroll = ARGS[1]
const file = ARGS[2]

const target_il =  -24.0
const target_lra = +11.0
const target_tp = -2.0

const loudnorm_query = "loudnorm=dual_mono=true:I=$(target_il):LRA=$(target_lra):tp=$(target_tp)"

function query_loudness(file)
  output_lines = FFMPEG.exe(`-i $file -filter:a $(loudnorm_query*":print_format=json") -vn -sn -f null NULL`, collect=true)

  loudnorm_start = nothing
  loudnorm_end = nothing
  for (i,line) in enumerate(output_lines)
    if startswith(line, "[Parsed_loudnorm")
      loudnorm_start = i + 1
      continue
    end 

    if loudnorm_start !== nothing && startswith(line, "}")
      loudnorm_end = i
      continue
    end
  end

  if loudnorm_end === nothing || loudnorm_start === nothing
    error("Failed to parse ffmpeg output")
  end

  json = join(output_lines[loudnorm_start:loudnorm_end], "\n")
  properties = JSON.Parser.parse(json)
end

format_loudnorm(p) = loudnorm_query * ":linear=true:measured_I=$(p["input_i"]):measured_LRA=$(p["input_lra"]):measured_tp=$(p["input_tp"]):measured_thresh=$(p["input_thresh"]):offset=$(p["target_offset"])"

# 1. Query properties of file

json = join(FFMPEG.exe(`-v error -show_entries stream=width,height -of json $(file)`, command=FFMPEG.ffprobe, collect=true), "\n")
properties = JSON.Parser.parse(json)
streams = properties["streams"]

filter!(!isempty, streams)
sizes = map(stream -> (stream["width"], stream["height"]), streams)

unique!(sizes)
width, height = only(sizes)

@sync begin
  global query0 = @async query_loudness(preroll)
  global query1 = @async query_loudness(file)
end
audio0_properties = fetch(query0)
audio1_properties = fetch(query1)

args = ```
-i $(preroll)
-i $(file)
-filter_complex 
"[0:v]scale=$(width):$(height):force_original_aspect_ratio=decrease,pad=$(width):$(height):-1:-1,setsar=1,fps=30,format=yuv420p[v0]; \
 [1:v]setsar=1,fps=30,format=yuv420p[v1];
 [0:a]$(format_loudnorm(audio0_properties))[a0];
 [1:a]$(format_loudnorm(audio1_properties))[a1];
  [v0][a0][v1][a1]concat=n=2:v=1:a=1[v][a]"
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

FFMPEG.exe(args)
