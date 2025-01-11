Pod::Spec.new do |s|
  s.name             = 'dart_lmdb2'
  s.version          = '1.0.0'
  s.summary          = 'iOS implementation of dart_lmdb2'
  s.description      = <<-DESC
iOS implementation of dart_lmdb2
                       DESC
  s.homepage         = 'http://github.com/grammatek/dart_lmdb2'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Grammatek ehf' => 'info@grammatek.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*', '../src/*.{h,c}'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Compile flags
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '$(inherited)',
    'ENABLE_BITCODE' => 'NO'
  }

  # Include CMake build
  s.preserve_paths = 'CMakeLists.txt'
  s.xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -force_load'
  }
end

