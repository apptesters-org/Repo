#!/bin/bash

get_app_info() {
  local bundle_id=$1

  # Make the search request
  local search_url="https://itunes.apple.com/lookup?bundleId=$bundle_id"
  local response=$(curl -s "$search_url")

  # Check for errors in the response
  error_message=$(echo "$response" | grep -o '"errorMessage":"[^"]*' | sed 's/"errorMessage":"//')
  if [[ -n "$error_message" ]]; then
    echo "❌ $error_message"
    return 1
  fi

  # Check if results[0] exists
  exists=$(echo "$response" | jq -r '.results[0]')
  if [[ "$exists" == "null" ]]; then
    echo "❌ No results found for the given app id: $trackId"
    return 1
  fi

  # Check if results[0] exists
  local exists=$(echo "$response" | jq -r '.results[0]')
  if [[ "$exists" == "null" ]]; then
    echo "Error: No results found for the given bundleID: $bundle_id"
    return 1
  fi

  # Initialize an empty JSON object
  json_string={}

  # Loop through the fields and assign their values to the JSON object
  fields=("trackName" "artistName" "price" "fileSizeBytes" "trackId" "primaryGenreName" "description" "bundleId" "artworkUrl512" "releaseNotes" "currentVersionReleaseDate" "version" "trackName" "trackViewUrl")

  for field in "${fields[@]}"; do
    value=$(echo "$response" | jq -r ".results[0].$field")
    json_string=$(jq -n --argjson json "$json_string" --arg field "$field" --arg value "$value" '$json + {($field): $value}')
  done

  # Print the final JSON string
  echo "$json_string"
}
