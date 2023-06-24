#!/bin/bash

apps_file="apps.json"
output_file="output.json"

# Check if apps_file doesn't exist
if [[ ! -f "$apps_file" ]]; then
  echo "Error: $apps_file file not found."
  exit 1
fi

# Load environment variables from .env file
if [ -f ".env" ]; then
  source src/esign/lib/setenv.sh
else
  echo "❌ .env file not found."
  exit 1
fi

source src/esign/lib/app-info.sh

# Get the current date in YYYY-MM-DD format
current_date=$(date +%Y-%m-%d)

# Release body template
release_body="## 📚 [AppTesters.org](https://apptesters.org) IPA Archive

1. [t.me/AppleTesters](https://t.me/AppleTesters) | Join our Telegram Group
2. [apptesters.org/purchase-certificate](https://apptesters.org/purchase-certificate) | Get  a Lifetime Certificate - Sign apps directly on your device using Esign. Notifications Supported.

**Features**:
- Largest Daily Updated IPA Library
- Wide Selection of Certificates
- Zero Revokes in the past 9 Months
- Instant Delivery
- Dedicated After Purchase Help and Guidance
- Exceptional Service Support
- Clean Modified IPAs
- No Tracking whatsoever
- Install Unlimited Apps
- Duplicate Apps Support
- Notification and VPN Compatibility
- More Exciting Features Coming Soon!

**IPA Files**:
"

# Check if environment variables are empty or not set
if [[ -z $GITHUB_TOKEN || -z $GITHUB_REPO ]]; then
  echo "Error: GitHub username, token, or repo is missing. Please check the .env file."
  exit 1
fi

extract_dylibs() {
  local app_bundle_path=$1
  local extracted_dylibs=()

  # Array of dylibs to ignore (case-insensitive)
  local ignore_dylibs=("libswift" "sideloadbypass")

  # Enable case-insensitive matching
  shopt -s nocasematch

  # Search for dylib files
  local dylib_files=$(find "$app_bundle_path" -name "*.dylib")

  # Process each dylib file
  for dylib_file in $dylib_files; do
    # Extract the dylib filename without extension
    local dylib_filename=$(basename "$dylib_file" .dylib)

    # Check if the dylib filename should be ignored
    local ignore=false
    for ignore_dylib in "${ignore_dylibs[@]}"; do
      case "$dylib_filename" in
      ${ignore_dylib}*)
        ignore=true
        break
        ;;
      esac
    done

    # Add the dylib filename to the list if not ignored
    if ! $ignore; then
      extracted_dylibs+=("$dylib_filename")
    fi
  done

  # Disable case-insensitive matching
  shopt -u nocasematch

  # Print the extracted dylibs as a JSON array
  (
    IFS='|'
    echo "${extracted_dylibs[*]}"
  )
}

create_app_json() {
  # Check if there are any IPA files in the current folder
  if ! compgen -G "ipas/*.ipa" >/dev/null; then
    echo "No IPA files found in the current folder. Exiting."
    exit 1
  fi

  # Create an array to store IPA file information
  json=""

  # Loop through each IPA file in the current folder
  for ipa_file in ipas/*.ipa; do
    echo "Processing: $ipa_file"

    # Unzip the IPA file
    unzip_folder="/tmp/unzipped_ipa"
    rm -rf "$unzip_folder" && mkdir -p "$unzip_folder"
    unzip -q "$ipa_file" -d "$unzip_folder"

    pljson=$(plutil -convert json -o - "$unzip_folder/Payload/"*.app/Info.plist)

    # Extract the desired information from the unzipped IPA contents
    name=$(echo "$pljson" | jq -r .CFBundleName | xargs)
    name_with_dots=$(echo "$name" | tr ' ' '.')

    version=$(echo "$pljson" | jq -r .CFBundleShortVersionString)

    # Rename the IPA file
    new_ipa_file="${name_with_dots}_${version}.ipa"
    mv "$ipa_file" "ipas/$new_ipa_file"
    echo "Renamed IPA file to: $new_ipa_file"

    bundle_identifier=$(echo "$pljson" | jq -r .CFBundleIdentifier)
    version_date=$(date -r "$unzip_folder/Payload/"*.app/Info.plist -u "+%Y-%m-%d")
    full_date=$(date -r "$unzip_folder/Payload/"*.app/Info.plist -u "+%Y-%m-%d%H:%M:%S" | tr -d ':-')
    download_url="https://github.com/$GITHUB_REPO/releases/download/$current_date/$new_ipa_file"
    size=$(stat -f%z "ipas/$new_ipa_file")

    # TODO: This doesn't work at all, i think variable is empty
    # Check if the download URL already exists in the apps.json file
    # existing_download_url=$(jq -r ".apps[] | select(.downloadURL == \"$download_url\") | .downloadURL" "$apps_file")
    # if [[ "$existing_download_url" == "$download_url" ]]; then
    #   echo "Download URL already exists in apps.json. Skipping: $ipa_file"
    #   continue
    # fi

    # Call the get_app_info function to retrieve app information
    appInfoResponse=$(get_app_info "$bundle_identifier")
    if [[ -z "$appInfoResponse" ]]; then
      echo "❌ Failed to lookup $bundle_identifier."
      exit 1
    fi

    name=$(echo "$appInfoResponse" | jq -r '.trackName')
    developer_name=$(echo "$appInfoResponse" | jq -r '.artistName')
    icon_url=$(echo "$appInfoResponse" | jq -r '.artworkUrl512')
    localized_description=$(echo "$appInfoResponse" | jq -r '.description')
    local primary_genre_name=$(echo "$appInfoResponse" | jq -r '.primaryGenreName')
    # Set the app_type based on the primary genre name
    if [[ "$primary_genre_name" == "Games" ]]; then
      app_type="2"
    else
      app_type="1"
    fi

    # Check if there is a folder named "igamegod" (case insensitive) recursively
    if find "$unzip_folder/Payload/"*.app -iname 'igamegod*' -type d | grep -q .; then
      # Extract the dylibs for the app
      extracted_dylibs=$(extract_dylibs "$unzip_folder/Payload/"*.app/"$bundle_id")
      # Prepend with "injected with ..., but only if there are dylibs"
      localized_description="Injected with iGameGod mods | $localized_description"
    fi

    # Extract the dylibs for the app
    extracted_dylibs=$(extract_dylibs "$unzip_folder/Payload/"*.app/"$bundle_id")
    # Prepend with "injected with ..., but only if there are dylibs"
    if [[ -n "$extracted_dylibs" ]]; then
      localized_description="Injected with $extracted_dylibs | $localized_description"
    fi

    info=$(jq -n \
      --arg name "$name" \
      --arg bundleIdentifier "$bundle_identifier" \
      --arg version "$version" \
      --arg versionDate "$version_date" \
      --arg fullDate "$full_date" \
      --arg downloadURL "$download_url" \
      --arg developerName "$developer_name" \
      --arg iconURL "$icon_url" \
      --arg icon "$icon_url" \
      --argjson type "$app_type" \
      --arg localizedDescription "$localized_description" \
      --argjson size "$size" \
      '{name: $name, realBundleID: $bundleIdentifier, bundleIdentifier: $bundleIdentifier, bundleID: $bundleIdentifier, version: $version, type: $type, versionDate: $versionDate, fullDate: $fullDate, down: $downloadURL, downloadURL: $downloadURL, developerName: $developerName, localizedDescription: $localizedDescription, icon: $icon, iconURL: $icon, size: $size}')

    # Append the release body with the app information
    release_body+="<img src=\"$icon_url\" width=\"35\" height=\"35\">"

    # Append the IPA information to the JSON string
    json+="$info,"
  done

  # Remove the trailing comma from the JSON string
  json=${json%,}

  # Enclose the JSON string in an array
  json="[$json]"

  echo "All .ipa files in the current folder have been processed."
  echo "$json" >"$output_file"
}

create_app_json

# Check if output.json file exists
if [[ ! -f "$output_file" ]]; then
  echo "output.json file not found. Exiting."
  exit 1
fi

# Check if output.json file is empty
if [[ ! -s "$output_file" ]]; then
  echo "output.json file is empty. No new apps found. Exiting."
  exit 1
fi

new_apps_array=$(jq -r '.' "$output_file")

# Check if new_apps_array is empty
if [[ -z "$new_apps_array" ]]; then
  echo "No new apps found in output.json. Exiting."
  exit 1
fi

# Update the apps.json file with the new app objects at the beginning of the array
jq --argjson newApps "$new_apps_array" '.apps = $newApps + .apps' "$apps_file" >"$apps_file.tmp" && mv "$apps_file.tmp" "$apps_file"
echo "New IPAs added to the beginning of apps.json file."

bash src/esign/delete-duplicates.sh || exit 1

cp "$apps_file" "index.html"

release_id=""
# Check if the release tag already exists
existing_release_response=$(curl -s -X GET \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_REPO/releases/tags/$current_date")
release_id=$(echo "$existing_release_response" | jq -r '.id')

release_body_json=$(jq -n \
  --arg body "$release_body" \
  '{body: $body}' | jq -c '.body')

if [[ "$release_id" == "null" ]]; then
  echo "Release for today's date does not exist. Creating a new release."
  # Create a release for today's date
  release_response=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -d '{
        "tag_name": "'"$current_date"'",
        "name": "Release for '"$current_date"'",
        "body": '"$release_body_json"',
        "draft": false,
        "prerelease": false
    }' "https://api.github.com/repos/$GITHUB_REPO/releases")

  release_id=$(echo "$release_response" | jq -r '.id')
fi

if [[ "$release_id" == "null" ]]; then
  echo "Release ID is null. Exiting."
  echo "$release_response $existing_release_response"
  exit 1
fi

# Iterate over .ipa files in the ipas folder
shopt -s nullglob
ipas=("ipas"/*.ipa)
for ipa_file in "${ipas[@]}"; do
  encoded_file_name=$(printf "%s" "$ipa_file" | awk -F/ '{print $NF}' | sed 's/ /%20/g')
  # Upload the .ipa file as an asset to the existing release
  upload_response=$(curl -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @"$ipa_file" \
    "https://uploads.github.com/repos/$GITHUB_REPO/releases/$release_id/assets?name=$encoded_file_name")

  # Display the upload response
  echo "Uploaded $(basename "$ipa_file") as an asset to GitHub release"
done

rm "$output_file" ipas/*.ipa
git add "$apps_file" >/dev/null 2>&1
git add index.html >/dev/null 2>&1
git commit -m "Update apps.json" >/dev/null 2>&1
git push origin main >/dev/null 2>&1
