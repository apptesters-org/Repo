#!/bin/bash

source src/esign/lib/app-info.sh

display_progress_bar() {
  local width=40
  local filled_length=$((width * counter / total_apps))
  local empty_length=$((width - filled_length))

  # Create the progress bar string
  local progress_bar="["
  progress_bar+="$(printf '#%.0s' $(seq 1 "$filled_length"))"
  progress_bar+="$(printf ' %.0s' $(seq 1 "$empty_length"))"
  progress_bar+="]"

  # Calculate the percentage complete
  local percentage=$((counter * 100 / total_apps))

  # Display the progress bar and percentage
  printf "\rProgress: %3d%% %s" "$percentage" "$progress_bar"
}

# Read the input JSON file
input_file="src/esign/apps.json"
input_json=$(cat "$input_file")

# Parse the input JSON and loop through each app
apps=$(echo "$input_json" | jq -c '.apps[]')
updated_apps=""

# Progress bar
counter=0
total_apps=$(echo "$input_json" | jq -r '.apps | length')

while IFS= read -r app; do
  counter=$((counter + 1))
  display_progress_bar

  name=$(echo "$app" | jq -r '.name')
  if [[ -z "$name" ]]; then
    echo "Error: Invalid name for app in input JSON."
    continue
  fi

  bundle_id=$(echo "$app" | jq -r '.realBundleID')
  if [[ -z "$bundle_id" ]]; then
    echo "Error: Invalid bundleID for app '$name' in input JSON."
    continue
  fi

  # Call the get_app_info function for each app
  updated_info=$(get_app_info "$bundle_id")
  if [[ $? -ne 0 ]]; then
    echo ""
    echo "Warning: Failed to retrieve app information for '$name' (bundleID: $bundle_id). Using the original input."
    echo ""
    updated_apps+="$app,"
    continue
  fi

  # Append the updated app info to the updated_apps string
  updated_apps+="$(echo "$app" | jq --argjson updated_info "$updated_info" '. + $updated_info'),"
done <<<"$apps"

echo ""

# Remove the trailing comma from the updated_apps string
updated_apps=${updated_apps%,}

# Create the final JSON object with the updated app information
updated_json=$(echo "$input_json" | jq --argjson updated_apps "[$updated_apps]" '.apps = $updated_apps')

# if updated json is empty exit
if [[ -z "$updated_json" ]]; then
  echo "Error: Failed to update the input JSON."
  exit 1
fi

# Write the updated JSON to a new file
output_file="src/esign/apps.json"
echo "$updated_json" >"$output_file"

bash src/esign/delete-duplicates.sh
