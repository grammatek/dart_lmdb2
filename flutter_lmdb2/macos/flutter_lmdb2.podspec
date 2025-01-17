Pod::Spec.new do |s|
  s.name             = 'flutter_lmdb2'
  s.version          = '0.9.99'
  s.summary          = 'LMDB for Flutter'
  s.description      = <<-DESC
LMDB library for Flutter with macOS support.
                       DESC
  s.homepage         = 'https://github.com/grammatek/dart_lmdb2'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Grammatek' => 'info@grammatek.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.vendored_libraries = '${PODS_ROOT}/../.symlinks/plugins/flutter_lmdb2/lib/src/native/macos/liblmdb.a'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '$(inherited) -force_load "${PODS_ROOT}/../.symlinks/plugins/flutter_lmdb2/lib/src/native/macos/liblmdb.a"',
    'VALID_ARCHS' => 'arm64 x86_64',
  }
  s.swift_version = '5.0'
end