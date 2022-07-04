 using DaggerGPU
 using FFMPEG
 using Distributed
 using JuliaConVideoManager
 # Hello world with FFMPEG
 #FFMPEG.exe("-version")
 postervideos = pkgdir(JuliaConVideoManager, "src/postervideos")
  # Let's try to run the bare bash script with no GPUs
 files = readdir(postervideos)                                                                                                                                                              19 intro = files[files .== "intro.mp4"] |> only
 # Ugly to have such stateful transformations but meh
 files = filter(x -> !startswith("intro", x), files)
 @show files[1]
 @show intro
 
function recipe(target, intro)
     """
     ffmpeg -i $intro -i "$target"  -filter_complex \
     "[0:v]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:-1:-1,setsar=1,fps=30,format=yuv420p[v0];
     [1:v]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:-1:-1,setsar=1,fps=30,format=yuv420p[v1];
     [v0][0:a][v1][1:a]concat=n=2:v=1:a=1[v][a]" \
     -map "[v]" -map "[a]" -c:v libx264 -c:a aac -movflags +faststart "processed/$target"
     """
end

@time for f in files
     FFMPEG.exe(recipe(f, intro))
end
