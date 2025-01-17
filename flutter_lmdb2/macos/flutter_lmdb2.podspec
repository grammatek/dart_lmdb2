Pod::Spec.new do |s|
  s.name             = 'flutter_lmdb2'
  s.version          = '0.0.1'
  s.summary          = 'LMDB for Flutter'
  s.description      = <<-DESC
LMDB library for Flutter with macOS support.
                       DESC
  s.homepage         = 'https://github.com/grammatek/dart_lmdb2'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Grammatek' => 'info@grammatek.com' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*'

  s.vendored_libraries = '${PODS_ROOT}/../.symlinks/plugins/flutter_lmdb2/lib/src/native/macos/liblmdb.a'

    s.pod_target_xcconfig = {
      'DEFINES_MODULE' => 'YES',
      'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
      'OTHER_LDFLAGS' => '$(inherited) -force_load "${PODS_ROOT}/../.symlinks/plugins/flutter_lmdb2/lib/src/native/macos/liblmdb.a"',
      'VALID_ARCHS' => 'arm64 x86_64',
      'IPHONEOS_DEPLOYMENT_TARGET' => '12.0'
    }
end