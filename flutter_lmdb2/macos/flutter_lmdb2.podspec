Pod::Spec.new do |s|
  s.name             = 'flutter_lmdb2'
  s.version          = '0.9.0'
  s.summary          = 'LMDB for Flutter'
  s.description      = 'LMDB library for Flutter with macOS support'
  s.homepage         = 'https://github.com/grammatek/dart_lmdb2'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Grammatek' => 'info@grammatek.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.13'

  s.vendored_libraries = 'Frameworks/liblmdb.dylib'
  s.preserve_paths = 'Frameworks/liblmdb.dylib'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'MACOSX_DEPLOYMENT_TARGET' => '10.13',
  }

  s.script_phase = {
      'name' => 'Copy and Configure LMDB Library',
      'execution_position' => :before_compile,
      'script' => <<~SCRIPT
        mkdir -p "${PODS_TARGET_SRCROOT}/Frameworks"
        cp -f "${PODS_TARGET_SRCROOT}/../lib/src/native/macos/liblmdb.dylib" "${PODS_TARGET_SRCROOT}/Frameworks/"
        install_name_tool -id "@rpath/liblmdb.dylib" "${PODS_TARGET_SRCROOT}/Frameworks/liblmdb.dylib"
      SCRIPT
    }
  s.prepare_command = <<-CMD
      mkdir -p Frameworks
      cp -f ../lib/src/native/macos/liblmdb.dylib Frameworks/
      install_name_tool -id "@rpath/liblmdb.dylib" Frameworks/liblmdb.dylib
    CMD
end