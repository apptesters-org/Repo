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


# this is shit so gotta seperate into its own func lol
# TIL: the namelist doesnt always have the .app name??
def get_app_name(nl: list[str]) -> str:
    for name in nl:
        if ".app/" in name and len(name.split("/")) >= 2:
            return "/".join(name.split("/")[:2])
    return ""


# uses same method as seashell cli:
# https://github.com/EntySec/SeaShell/blob/8ae1ecba722ba303c961c537633b663717fcfbe7/seashell/core/ipa.py#L189
def no_seashell(path: str) -> dict:
    with zipfile.ZipFile(path) as zf:
        app: str = get_app_name((nl := zf.namelist()))

        if f"{app}/mussel" in nl:
            return {"unsafe": 1}

        with zf.open((pl_name := f"{app}/Info.plist")) as pl:
            plist = plistlib.load(pl)
        if "CFBundleSignature" in plist:
            return {"unsafe": 1}

    return {"pl": plist, "nl": nl, "pl_name": pl_name}


# if called, guaranteed that icon is not yet saved
def get_single_bundle_id(url, name = "temp.ipa") -> dict:
    with open(name, "wb") as f:
        f.write(requests.get(url).content)

    os.makedirs("icons", exist_ok=True)
        
    try:
        assert(zipfile.is_zipfile(name))
    except AssertionError:
        print(f"[!] bad zipfile: {os.path.basename(url)} ({url})")
        return {"error": 1}

    try:
        assert("unsafe" not in (sscheck := no_seashell(name)))
    except AssertionError:
        print(f"[!] seashell detected in: {os.path.basename(url)} ({url})")
        return {"error": 1}

    with zipfile.ZipFile(name) as archive:
        bundleId = sscheck["pl"]["CFBundleIdentifier"]

        if (res := save_appstore_icon(bundleId))["err"]:
            try:
                icon_path = sscheck["pl"]["CFBundleIcons"]["CFBundlePrimaryIcon"]["CFBundleIconFiles"][0]
                for name in sscheck["nl"]:
                    if icon_path in name:
                        icon_path = name  # im so tired
                        break
            except (KeyError, IndexError):
                # is this doing what i think it's doing..?
                icon_path = f"{os.path.dirname(sscheck["pl_name"])}/{sscheck["pl"]["CFBundleIconFiles"][0]}"

            with archive.open(icon_path) as orig, open(f"icons/{bundleId}.png", "wb") as new:
                new.write(orig.read())

    return {"bundle": bundleId, "genre": res["genre"]}
