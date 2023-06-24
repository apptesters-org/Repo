#!/bin/bash

# Read the JSON file into a variable
input_json=$(cat apps.json)

# Use jq to filter and keep only the latest version of each app
filtered_json=$(echo "$input_json" | jq -c '.apps | group_by(.realBundleID) | map(max_by(.versionDate)) | sort_by(.versionDate) | reverse')

# Update just the apps object in input_json
filtered_input=$(echo "$input_json" | jq --argjson filtered_json "$filtered_json" '.apps = $filtered_json')

# Output the filtered JSON
echo "$filtered_input" >apps.json
