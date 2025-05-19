#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_lmdb2.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_lmdb2'
  s.module_name      = 'flutter_lmdb2'
  s.version          = '0.9.5'
  s.summary          = 'LMDB for Flutter'
  s.description      = 'LMDB library for Flutter with iOS support'
  s.homepage         = 'https://github.com/grammatek/dart_lmdb2'
  s.license          = { :type => 'MIT', :file => '../../LICENSE' }
  s.author           = { 'Grammatek' => 'info@grammatek.com' }
  s.source           = { :git => 'https://github.com/grammatek/dart_lmdb2.git' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  s.public_header_files = 'Classes/**/*.h'

  # Base configuration
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'VALID_ARCHS' => 'arm64 x86_64'
  }

  # Point directly to the architecture-specific libraries with conditional logic
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS[sdk=iphoneos*]' => '$(inherited) -force_load "${PODS_ROOT}/../.symlinks/plugins/flutter_lmdb2/lib/src/native/ios/device/liblmdb.a"',
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => '$(inherited) -force_load "${PODS_ROOT}/../.symlinks/plugins/flutter_lmdb2/lib/src/native/ios/simulator/liblmdb.a"',
  }
end
