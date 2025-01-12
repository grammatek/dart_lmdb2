Pod::Spec.new do |s|
  s.name             = 'flutter_lmdb2'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for LMDB'
  s.description      = <<-DESC
Flutter plugin for LMDB database
                       DESC
  s.homepage         = 'http://github.com/grammatek/dart_lmdb2'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Grammatek ehf' => 'info@grammatek.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*', '../src/*.{h,c}'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Include the compiled static library
  s.vendored_libraries = 'liblmdb.a'

  # Compile flags
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'VALID_ARCHS' => 'arm64 x86_64',
    'OTHER_LDFLAGS' => '$(inherited) -force_load "${PODS_ROOT}/../.symlinks/plugins/flutter_lmdb2/ios/liblmdb.a"',
    'ENABLE_BITCODE' => 'NO'
  }
end

