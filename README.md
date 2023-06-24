# eSign Tools for App Management 📲

Welcome to eSign Tools, a collection of utilities for managing and enhancing your app releases. This repository includes two main components: Cleaner and Releaser. Follow the instructions below to utilize these tools effectively.

## Cleaner

The Cleaner tool helps you prepare your app for distribution by performing various tasks and optimizations. It offers the following features:

- Lists the injections in the IPA, like Bea for BeReal or iGameGod for Plants vs Zombies.
- Utilizes plist for storing version, name, date, and size information.
- Provides a download URL to access the latest release on GitHub.
- Retrieves the app's icon URL from iTunes, eliminating the need to store PNG files locally.
- Adds a category classification (app or game) to facilitate easy filtering for eSign purposes.

## Releaser

The Releaser tool streamlines the release process by automating essential tasks. It empowers you to:

- Create GitHub releases effortlessly.
- Upload release assets directly to the GitHub repository.
- Rename the IPA file to follow the format `name_version.ipa` for improved organization.
- Append new IPAs to the beginning of the `apps.json` file.
- Commit changes to the `apps.json` file and push them to your repository.

# Release Process 🚀

This repository contains the release process for your project. Follow the steps below to add IPAs and run the necessary script.

## Step 1: Add IPAs

To initiate the release process, add the IPAs you wish to distribute to the `/ipa/` folder within this repository. The script will handle the extraction of dylibs and other relevant tasks.

## Step 2: Update .env File

Before running the script, you need to update the `.env` file with your credentials. Follow these steps:

1. Locate the `.env.example` file in the root folder of this repository.
2. Rename the file from `.env.example` to `.env`.
3. Open the `.env` file using a text editor.
4. Update the following fields with your credentials:

   ```plaintext
   GITHUB_TOKEN="<Your GitHub Access Token with release access>"
   GITHUB_REPO="<ORG_NAME/REPO_NAME>"
   ```

   You can find the necessary credentials in your respective accounts (GitHub and iTunes).

## Step 3: Run the Update eSign Repo Script

After adding the IPAs and updating the `.env` file, execute the `release-new-ipas.sh` script to update the eSign JSON file with the required release information. Follow these steps to run the script:

1. Open a terminal or command prompt.
2. Navigate to the root folder of this repository.
3. Run the following command:

   ```bash
   yarn start
   ```

Enjoy a streamlined and efficient release process with eSign Tools! If you have any questions or need further assistance, please don't hesitate to reach out. Happy app management! 🎉
