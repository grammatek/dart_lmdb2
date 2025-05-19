# Release Process for dart_lmdb2 and flutter_lmdb2

This document describes the release process for the `dart_lmdb2` and `flutter_lmdb2` packages, which are maintained in the same repository. Native libraries are no longer bundled with the packages - instead, they are downloaded on-demand using the `fetch_native` command.

## Overview

The release process consists of these steps:

1. Update package versions and changelogs
2. Create and push a Git tag in the specific format
3. Wait for GitHub Actions to build native libraries and create release
4. Publish to pub.dev using standard Dart tooling

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

Tags must follow this specific format to trigger the GitHub Actions workflow:
- For dart_lmdb2: `dart_lmdb2_vX.Y.Z` (e.g., `dart_lmdb2_v0.9.8`)
- For flutter_lmdb2: `flutter_lmdb2_vX.Y.Z` (e.g., `flutter_lmdb2_v0.9.3`)

```bash
# For dart_lmdb2
git tag -a dart_lmdb2_v0.9.8

# For flutter_lmdb2
git tag -a flutter_lmdb2_v0.9.3

# Push the tag
git push origin <tag_name>
```

## Step 3: Wait for GitHub Actions to Build

After pushing the tag, GitHub Actions will automatically:

1. Build all platform-specific native libraries
2. Generate a manifest.json with version information
3. Create a GitHub release with the native libraries archive
4. Attach the archive to the release

You can monitor the workflow progress in the "Actions" tab of the GitHub repository.

## Step 4: Publish to pub.dev

Once the GitHub Actions workflow completes successfully, you can publish the package:

1. Navigate to the package directory
   ```bash
   # For dart_lmdb2
   cd dart_lmdb2

   # For flutter_lmdb2
   cd flutter_lmdb2
   ```

2. (Optional) Verify that native libraries are available in the GitHub release
   ```bash
   # Check if the release exists
   curl -I https://github.com/grammatek/dart_lmdb2/releases/download/<tag_name>/<package_name>-<version>-native-libs.tar.gz
   ```

3. Publish using standard Dart tooling
   ```bash
   dart pub publish

   # Or for a dry-run first
   dart pub publish --dry-run
   ```

## Native Library Management

### For Package Users

After installing the package, users need to download native libraries:

```bash
# For dart_lmdb2 users
dart run dart_lmdb2:fetch_native

# For flutter_lmdb2 users
dart run flutter_lmdb2:fetch_native
```

The libraries are downloaded from GitHub releases and include a manifest.json for version verification.

### Architecture

- Native libraries are built by GitHub Actions for all supported platforms
- Libraries are packaged with a manifest.json containing version information
- The `fetch_native` command downloads the correct version based on the installed package
- Libraries are cached locally and only re-downloaded when versions change

## Test Releases

For testing the release process without publishing to pub.dev:

1. Create a test tag: `dart_lmdb2_test_<identifier>` or `flutter_lmdb2_test_<identifier>`
2. Push the tag to trigger the workflow
3. Once the workflow completes, test the package locally without publishing

## Additional Notes

- **Sequential Releases**: If you need to release both packages, always release `dart_lmdb2` first, since `flutter_lmdb2` depends on it.

- **Platform Support**: Native libraries are built for:
  - Android (arm64-v8a, x86_64)
  - iOS (device arm64, simulator x86_64 + arm64)
  - Linux (x86_64)
  - macOS (universal binary with arm64 + x86_64)
  - Windows (x86_64)

- **Version Matching**: The fetch_native command automatically detects and downloads the correct version based on the installed package version.
