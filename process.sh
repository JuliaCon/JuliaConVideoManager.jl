echo "-- Download the intro"

# curl "https://juliacon2020-uploads.s3.us-east-2.amazonaws.com/public/UNKNWN%3Aadditionalvideomaterial%3Aanimation-lo-res-400.mov" -o "intro.mov"

echo "-- Download video"

# Does ffmpeg care about the file ending?
# curl "${VIDEO_URL}" --output "${ID}.mp4"

echo "-- Process the video"
mkdir -p out
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. processing.jl "intro.mov" "${ID}.mp4"

echo "--- Upload the processed video"
# buildkite-agent artifact upload "${ID}.mp4"

# echo "--- Trigger Zapier pipeline"
# curl -X POST "https://hooks.zapier.com/hooks/catch/12874263/bw07v2l/" \
#    -d '{
#        "ID": "'${ID}'",
#        "BUILDKITE_BUILD_NUMBER": "'${BUILDKITE_BUILD_NUMBER}'",
#        "BUILDKITE_JOB_ID": "'${BUILDKITE_JOB_ID}'"
#     }'