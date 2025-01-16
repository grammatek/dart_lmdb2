# flutter_lmdb2 example Application

This example application demonstrates how to integrate [flutter_lmdb2](https://pub.dev/packages/flutter_lmdb2) into your app.

## Prerequisites
### General

Fetch all dependencies and precompiled binaries:

```bash
flutter pub get
dart run flutter_lmdb2:fetch_native
```
### Android

Enable Android and build an APK:

```bash
flutter config --enable-android
flutter build apk --release
```

### iOS

Enable building for iOS/iPadOS and fetch all prerequisites for these platforms:

```bash
flutter config --enable-ios
cd ios/
pod install
cd ..
```

### Linux

TODO

### MacOS

TODO

### Windows

TODO

## Running the app

After you have followed the prerequisite steps, run the app normally via:

```bash
flutter run
```
an choose an appropriate target device.

## Getting Started with development

This project is a starting point for a Flutter application based on flutter_lmdb2.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the [online documentation](https://docs.flutter.dev/), which offers tutorials, samples, guidance on mobile development, and a full API reference.

For getting started with flutter_lmdb2, browse the documentation of [dart_lmdb2](https://pub.dev/packages/dart_lmdb2), which provides all the APIs.
