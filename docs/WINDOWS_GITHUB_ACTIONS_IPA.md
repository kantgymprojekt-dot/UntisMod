# Build the Untis iOS IPA from Windows with GitHub Actions

This project is SwiftUI. Windows cannot compile it locally, so GitHub Actions uses a hosted macOS runner with Xcode. The workflow in `.github/workflows/build-unsigned-ipa.yml` creates an **unsigned iPhone-device IPA**. It does not need a Mac, signing certificate, provisioning profile, or Apple password in GitHub.

## 1. Create a GitHub repository

1. Sign in to GitHub in your browser and choose **New repository**.
2. Give it a name such as `Untis-iOS`.
3. Choose **Private**. The project recreates a third-party app's look and includes its branding; do not publish the source assets or APK files publicly.
4. Create the repository. Do not initialize it with another README, `.gitignore`, or license because this project already contains those files.

## 2. Download and extract this project

1. Download the project ZIP supplied with this tutorial.
2. Extract it on Windows.
3. Open the extracted `UntisMobileiOS` folder. The folder should contain `UntisMobile.xcodeproj`, `UntisMobile`, `.github`, and `README.md`.

## 3. Set a unique Bundle Identifier

The project currently contains the example identifier `com.example.untismobileclone` in the Xcode project settings. Before signing and installing, change it to an identifier that is unique to your app, for example `com.yourchosenname.untis` (replace `yourchosenname` with your own non-private alias).

Open `UntisMobile.xcodeproj/project.pbxproj` in a text editor and replace **both** occurrences of:

```text
com.example.untismobileclone
```

with your chosen identifier. Use lowercase letters/numbers and dots; do not use spaces. Save the file.

The home-screen display name is already set to `Untis` and does not need changing.

## 4. Publish the project with GitHub Desktop (recommended)

1. Install GitHub Desktop from its official site and sign in to GitHub.
2. In GitHub Desktop choose **File → Add local repository** if the extracted folder is already a Git repository; otherwise choose **File → New repository** and set the extracted project folder as the local path.
3. Make sure the project contents are inside the repository folder. The `.github` directory is hidden in Windows Explorer by default; enable **View → Show → Hidden items** to confirm `.github/workflows/build-unsigned-ipa.yml` exists.
4. Do not copy the original `.apk` files from `Reference/OriginalAPKParts/` into the repository. They are not needed to compile the iOS app; the iOS asset catalog is already in `UntisMobile/Assets.xcassets`.
5. In GitHub Desktop, commit the files, then click **Publish repository**. Keep **Keep this code private** selected. GitHub Desktop includes hidden workflow files when publishing the repository.

GitHub documents the Windows flow for adding a local repository and publishing it here: https://docs.github.com/en/desktop/adding-and-cloning-repositories/adding-an-existing-project-to-github-using-github-desktop?platform=windows

## 5. Start the build

1. In the repository on GitHub, open the **Actions** tab.
2. Select **Build Untis iOS IPA** in the left sidebar.
3. Press **Run workflow** and choose the `main` branch.
4. Press the green **Run workflow** button.
5. Open the new workflow run. Wait for the `build` job to finish with a green checkmark. If it fails, open the failed step and read the first compiler error in its log.

A push to `main` also starts a build automatically.

## 6. Download the IPA

1. Open the successful workflow run.
2. Scroll down to **Artifacts**.
3. Download **Untis-unsigned-IPA**.
4. Extract that artifact ZIP. Inside it you will find `Untis-unsigned.ipa` and `Untis-build-info.txt`.

The IPA is for a physical iPhone/iPad (`iphoneos`), not the iOS Simulator.

## 7. Sign and install it on the iPhone

The generated IPA is deliberately **unsigned**. iOS will not install it as-is. The simplest Windows route is to use a reputable sideloading utility that can sign an existing IPA with your own Apple ID. For example, Sideloadly's official site documents the Windows flow: load the IPA, authenticate with your Apple ID in the utility, and install to the connected device.

1. Download the Windows installer only from the utility's official website.
2. Connect your iPhone by USB, unlock it, and trust the computer if iOS asks.
3. Open the sideloading utility and select `Untis-unsigned.ipa`.
4. Sign it using your own Apple ID through the utility's documented flow; do not put Apple credentials in GitHub, source files, workflow YAML, or chat.
5. Start the install. Follow the on-device trust/developer-mode prompts if iOS displays them.

A free Apple account's sideloaded-app signing expires periodically (commonly after 7 days), so the app may need to be refreshed/re-signed. The GitHub build itself does **not** consume a sideloaded-app slot; installing the signed app is the step that may use one. Keep your remaining device app slots in mind before installing.

## 8. Updating the app

After changing Swift code or assets, commit/push to `main` or run **Build Untis iOS IPA** manually. Download the newest artifact and reinstall/re-sign it. Keep the Bundle Identifier the same for updates so iOS treats it as the same app. Changing the Bundle Identifier creates a separate app identity.

## Troubleshooting

- **No workflow appears:** confirm `.github/workflows/build-unsigned-ipa.yml` exists on the default `main` branch and that GitHub Actions is enabled for the repository.
- **Scheme not found:** ensure `UntisMobile.xcodeproj/xcshareddata/xcschemes/UntisMobile.xcscheme` was uploaded.
- **Compiler error:** open the failed job's `xcodebuild` log. This is a source/build error, not an Apple signing error.
- **App cannot be installed because it is unsigned:** that is expected until the IPA is signed by the Windows sideloading tool.
- **Signing or provisioning fails:** confirm the Bundle Identifier is unique for your Apple account and follow the sideloading tool's error message. Do not upload certificates, private keys, or passwords to the repository.

## What this workflow does and does not do

- It builds an iPhone/iPad device app using GitHub's hosted macOS 26 runner and Xcode.
- It packages that app into an unsigned `.ipa` and uploads it as a GitHub Actions artifact.
- It does not install the app on your phone, sign it, create a provisioning profile, or guarantee that the current SwiftUI source compiles on the first attempt. The first workflow run is the real compile test.
