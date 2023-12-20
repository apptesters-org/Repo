import os
import zipfile
import plistlib
from tempfile import NamedTemporaryFile as NTF

import requests
from PIL import Image


# returns genre id
def save_appstore_icon(bundle: str) -> dict:
    x = requests.get(f"https://itunes.apple.com/lookup?bundleId={bundle}&limit=1&country=US").json()
    try:
        icon_url = x["results"][0]["artworkUrl512"]
        genres = x["results"][0]["genreIds"]
    except (KeyError, IndexError):
        # type 1 = app
        return {"genre": 1, "err": True}  # invalid appstore app, will have to extract from ipa
 
    with NTF() as tmp:
        tmp.write(requests.get(icon_url).content)
        with Image.open(tmp.name) as img:
            img.save(f"icons/{bundle}.png", "PNG")  # usually jpg, so we save as png instead
    
    if "6014" in genres or any(genre.startswith("70") for genre in genres):
        return {"genre": 2, "err": False}  # type 2 = game
    return {"genre": 1, "err": False}


# if called, guaranteed that icon is not yet saved
def get_single_bundle_id(url, name="temp.ipa") -> dict:
    with open(name, "wb") as f:
        f.write(requests.get(url).content)

    os.makedirs("icons", exist_ok=True)
        
    try:
        assert(zipfile.is_zipfile(name))
    except AssertionError:
        print(f"[!] bad zipfile: {os.path.basename(url)} ({url})")
        return
        
    with zipfile.ZipFile(name) as archive:
        for file_name in (nl := archive.namelist()):
            if file_name.endswith(".app/Info.plist"):
                info_file = file_name
                break

        with archive.open(info_file) as fp:
            pl = plistlib.load(fp)
            bundleId = pl["CFBundleIdentifier"]

        if (res := save_appstore_icon(bundleId))["err"]:
            try:
                icon_path = pl["CFBundleIcons"]["CFBundlePrimaryIcon"]["CFBundleIconFiles"][0]
                for name in nl:
                    if icon_path in name:
                        icon_path = name  # im so tired
                        break
            except (KeyError, IndexError):
                icon_path = f"{os.path.dirname(info_file)}/{pl["CFBundleIconFiles"][0]}"

            with archive.open(icon_path) as orig, open(f"icons/{bundleId}.png", "wb") as new:
                new.write(orig.read())

    return {"bundle": bundleId, "genre": res["genre"]}


# is this even used ??????? -- edit: guess not lol
# def generate_bundle_id_csv(token, repo_name="asdfzxcvbn/apptesters-repo"):
#     g = github.Github(token)
#     repo = g.get_repo(repo_name)
#     releases = repo.get_releases()

#     df = pd.DataFrame(columns=["name", "bundleId"])

#     for release in releases:
#         print(release.title)
#         for asset in release.get_assets():
#             if not asset.name.endswith("ipa"):
#                 continue
#             name = asset.name[:-4]
#             print(asset.name)

#             try:
#                 app_name = name.split("-", 1)[0]
#             except Exception:
#                 app_name = name

#             if app_name in df.name.values:
#                 continue
#             df = pd.concat(
#                 [
#                     df,
#                     pd.DataFrame(
#                         {
#                             "name": [app_name],
#                             "bundleId": get_single_bundle_id(asset.browser_download_url)
#                         }
#                     )
#                 ],
#                 ignore_index=True
#             )

#     df.to_csv("bundleId.csv", index=False)


# if __name__ == "__main__":
#     generate_bundle_id_csv(None)