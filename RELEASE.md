# Release Process for dart_lmdb2 and flutter_lmdb2

This document describes the release process for the `dart_lmdb2` and `flutter_lmdb2` packages, which are maintained in the same repository. Since both packages contain native libraries that are not checked into Git, the release process includes building and bundling these libraries.

## Overview

The release process consists of these main steps:

1. Update package versions and changelogs
2. Create and push a Git tag in the specific format
3. Wait for GitHub Actions to build all native libraries
4. Download the release assets
5. Publish to pub.dev

## Step 1: Update Package Versions and Changelogs

For the package you want to release:

1. Update the version in the `pubspec.yaml` file
   ```yaml
   name: dart_lmdb2  # or flutter_lmdb2
   version: x.y.z    # new version here
   ```

2. Update the `CHANGELOG.md` file with the new version and release notes
   ```markdown
   ## x.y.z

   * Description of changes
   * Bug fixes
   * New features
   ```

3. If releasing `flutter_lmdb2`, ensure it depends on the correct version of `dart_lmdb2` in its `pubspec.yaml`

4. Commit these changes to the repository
   ```bash
   git add -u
   git commit -m "Prepare release of [package_name] vX.Y.Z"
   ```

## Step 2: Create and Push a Git Tag

Tags must follow this specific format:
- For dart_lmdb2: `dart_lmdb2_vX.Y.Z` (e.g., `dart_lmdb2_v0.9.8`)
- For flutter_lmdb2: `flutter_lmdb2_vX.Y.Z` (e.g., `flutter_lmdb2_v0.9.3`)

```bash
# For dart_lmdb2
git tag dart_lmdb2_v0.9.8

# For flutter_lmdb2
git tag flutter_lmdb2_v0.9.3

# Push the tag
git push origin <tag_name>
```

## Step 3: Wait for GitHub Actions to Build

After pushing the tag, two GitHub Actions workflows will run in sequence:

1. `LMDB2` (main workflow in dart.yml)
   - Builds all platform-specific native libraries
   - Runs tests and validations

2. `Create Release with Binaries` (create-release.yml)
   - Triggered when the main workflow completes successfully
   - Creates a GitHub release based on the tag
   - Generates a tarball containing all native libraries
   - Attaches the tarball to the release

You can monitor these workflows in the "Actions" tab of the GitHub repository.

## Steps 4 & 5: Download Release Assets and Publish (Automated)

We provide an automated release script that handles downloading the assets and publishing:

```bash
# Install dependencies
cd dart_lmdb2/dart_lmdb2
dart pub get

# Run the release script for dart_lmdb2
dart run ../tool/release.dart --package=dart_lmdb2

# Run the release script for flutter_lmdb2
dart run ../tool/release.dart --package=flutter_lmdb2
```

The script will:
1. Auto-detect the package version from pubspec.yaml
2. Download the native libraries tarball from GitHub releases
3. Extract it to the correct location
4. Verify the extraction was successful
5. Publish to pub.dev

### Script Options

```
Usage: dart run tool/release.dart [options]

Options:
  --package=<name>  Package to release (dart_lmdb2 or flutter_lmdb2)
  --tag=<tag>       Specific tag to use (defaults to latest matching tag)
  --no-pub          Skip publishing to pub.dev (extract libraries only)
  --help            Show this help message
```

## Steps 4 & 5: Download Release Assets and Publish (Manual Alternative)

If you prefer to perform these steps manually:

1. Go to the "Releases" section of the repository
2. Find the release corresponding to your tag
3. Download the `[package_name]-[version]-native-libs.tar.gz` file
   (e.g., `dart_lmdb2-0.9.8-native-libs.tar.gz` or `flutter_lmdb2-0.9.3-native-libs.tar.gz`)

4. Clone a clean copy of the repository at the tagged commit
   ```bash
   git clone --depth 1 --branch <tag_name> https://github.com/grammatek/dart_lmdb2.git
   ```

5. Extract the downloaded native libraries to the package's `lib/src/native` directory
   ```bash
   # For dart_lmdb2
   cd dart_lmdb2/dart_lmdb2
   tar -xzf /path/to/downloaded/dart_lmdb2-0.9.8-native-libs.tar.gz -C .

   # For flutter_lmdb2
   cd dart_lmdb2/flutter_lmdb2
   tar -xzf /path/to/downloaded/flutter_lmdb2-0.9.3-native-libs.tar.gz -C .
   ```

6. Verify that the native libraries are correctly placed in the package
   ```bash
   ls -R lib/src/native
   ```

7. Publish to pub.dev
   ```bash
   # For dart_lmdb2
   cd dart_lmdb2/dart_lmdb2
   dart pub publish

   # For flutter_lmdb2
   cd dart_lmdb2/flutter_lmdb2
   flutter pub publish
   ```

## Additional Notes

- **Sequential Releases**: If you need to release both packages, always release `dart_lmdb2` first, since `flutter_lmdb2` depends on it.

- **GitHub Actions Access**: The GitHub Actions workflows require permission to:
  - Build the code
  - Create releases
  - Upload assets to releases

- **Troubleshooting**: If the automated workflows fail:
  1. Check the workflow logs in the GitHub Actions tab
  2. For build issues, you may need to manually build the native libraries
  3. For release issues, you can create a GitHub release manually and attach the built artifacts

- **Library Structure**: The native libraries are organized as follows:
  ```
  lib/src/native/
  ├── android/
  │   ├── arm64-v8a/
  │   └── x86_64/
  ├── ios/
  │   ├── device/
  │   └── simulator/
  ├── linux/
  ├── macos/
  └── windows/
  ```

  Each directory contains the platform-specific libraries needed for that platform.