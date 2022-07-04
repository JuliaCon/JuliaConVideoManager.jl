echo "-- Process video"
echo ${ID}
echo ${VIDEO_URL}

echo "--- Upload the processed video"
# buildkite-agent artifact upload "test/results.json"

echo "--- Trigger Zapier pipeline"
curl -X POST "https://hooks.zapier.com/hooks/catch/12874263/bw07v2l/" \
   -d '{
       "ID": "'${ID}'",
       "BUILDKITE_BUILD_NUMBER": "'${BUILDKITE_BUILD_NUMBER}'",
       "BUILDKITE_JOB_ID": "'${BUILDKITE_JOB_ID}'"
    }'