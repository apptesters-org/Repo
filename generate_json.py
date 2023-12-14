from github import Github
import json
import argparse
import pandas as pd
from get_bundle_id import get_single_bundle_id
import os
import shutil


def transform_object(original_object):
    transformed_object = {**original_object, 'apps': None}

    app_map = {}

    for app in original_object['apps']:
        name, bundle_identifier, version, version_date, size, download_url, developer_name, localized_description, icon_url = (
            app['name'], app['bundleIdentifier'], app['version'], app['versionDate'],
            app['size'], app['downloadURL'], app['developerName'], app['localizedDescription'], app['iconURL']
        )

        if name not in app_map:
            app_map[name] = {
                'name': name,
                'bundleIdentifier': bundle_identifier,
                'developerName': developer_name,
                'localizedDescription': localized_description,
                'iconURL': icon_url,
                'versions': [],
            }

        app_map[name]['versions'].append({
            'version': version,
            'date': version_date,
            'size': size,
            'downloadURL': download_url,
        })

    for name, app_info in app_map.items():
        app_info['versions'].sort(key=lambda x: x['date'], reverse=True)

    transformed_object['apps'] = list(app_map.values())

    return transformed_object


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-t", "--token", help="Github token")
    args = parser.parse_args()
    token = args.token

    out_file = "apps.json"
    clone_file = "index.html"

    with open(out_file, "r") as f:
        data = json.load(f)

    if os.path.exists("bundleId.csv"):
        df = pd.read_csv("bundleId.csv")
    else:
        df = pd.DataFrame(columns=["name", "bundleId"])

    # clear apps
    data["apps"] = []

    g = Github(token)
    repo_name = "apptesters-org/Repo"
    repo = g.get_repo(repo_name)
    releases = repo.get_releases()

    for release in releases:
        print(release.title)

        for asset in release.get_assets():
            if not asset.name.endswith(".ipa"):
                continue
            name = asset.name[:-4]
            date = asset.created_at.strftime("%Y-%m-%d")
            full_date = asset.created_at.strftime("%Y%m%d%H%M%S")
            try:
                app_name, version, tweaks = name.split("_", 2)
                tweaks, _ = tweaks.split("@", 1)
                if tweaks:
                    tweaks = "Injected with " + tweaks[:-1].replace("_", " ")
            except:
                app_name = name
                version = "Unknown"
                tweaks = None

            if app_name in df.name.values:
                bundle_id = str(df[df.name == app_name].bundleId.values[0])
            else:
                bundle_id = get_single_bundle_id(asset.browser_download_url)
                df = pd.concat([df, pd.DataFrame(
                    {"name": [app_name], "bundleId": [bundle_id]})], ignore_index=True)

            data["apps"].append(
                {
                    "name": app_name,
                    "realBundleID": bundle_id,
                    "bundleID": bundle_id,
                    "bundleIdentifier": bundle_id,
                    "version": version,
                    "versionDate": date,
                    "fullDate": full_date,
                    "size": asset.size,
                    "down": asset.browser_download_url,
                    "downloadURL": asset.browser_download_url,
                    "developerName": "",
                    "localizedDescription": tweaks,
                    "icon": f"https://raw.githubusercontent.com/{repo_name}/main/icons/{bundle_id}.png",
                    "iconURL": f"https://raw.githubusercontent.com/{repo_name}/main/icons/{bundle_id}.png"
                }
            )
            data["apps"].sort(key=lambda x: x["fullDate"], reverse=True)

    df.to_csv("bundleId.csv", index=False)

    with open(out_file, 'w') as json_file:
        json.dump(data, json_file, indent=2)

    with open(out_file, 'r') as file:
        original_object = json.load(file)

    transformed_object = transform_object(original_object)
    
    with open(out_file, 'w') as file:
        json.dump(transformed_object, file, indent=2)
    
    shutil.copyfile(out_file, clone_file)
