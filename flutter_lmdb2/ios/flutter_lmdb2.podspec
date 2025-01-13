#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_lmdb2.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_lmdb2'
  s.module_name      = 'flutter_lmdb2'
  s.version          = '1.0.0'
  s.summary          = 'LMDB for Flutter'
  s.description      = 'LMDB library for Flutter with iOS support'
  s.homepage         = 'https://github.com/grammatek/dart_lmdb2'
  s.license          = { :type => 'MIT', :file => '../../LICENSE' }
  s.author           = { 'Grammatek' => 'info@grammatek.com' }
  s.source           = { :git => 'https://github.com/grammatek/dart_lmdb2.git' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'

  s.ios.deployment_target = '12.0'

  s.public_header_files = 'Classes/**/*.h'
  s.vendored_libraries = 'liblmdb.a'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '$(inherited) -force_load "${PODS_ROOT}/../.symlinks/plugins/flutter_lmdb2/ios/liblmdb.a"',
    'VALID_ARCHS' => 'arm64 x86_64',
    'IPHONEOS_DEPLOYMENT_TARGET' => '12.0'
  }
end
