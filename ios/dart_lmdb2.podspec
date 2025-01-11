Pod::Spec.new do |s|
  s.name             = 'dart_lmdb2'
  s.version          = '1.0.0'
  s.summary          = 'LMDB for Flutter'
  s.description      = 'LMDB library for Flutter with iOS support'
  s.homepage         = 'https://github.com/grammatek/dart_lmdb2'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Grammatek' => 'info@grammatek.com' }
  s.source           = { :git => 'https://github.com/grammatek/dart_lmdb2.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'  # Minimum iOS Version korrigiert

  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.vendored_libraries = 'liblmdb.a'

  s.dependency 'Flutter'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '$(inherited) -force_load',
    'VALID_ARCHS' => 'arm64 x86_64',
    'IPHONEOS_DEPLOYMENT_TARGET' => '12.0'
  }

  # Keine module.modulemap notwendig, stattdessen:
  s.module_name = 'dart_lmdb2'
end
