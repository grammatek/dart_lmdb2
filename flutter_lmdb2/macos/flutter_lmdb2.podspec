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

  s.vendored_libraries = 'Frameworks/liblmdb.dylib'
  s.preserve_paths = 'Frameworks/liblmdb.dylib'

  s.script_phase = {
      :name => 'Copy Native Libraries',
      :execution_position => :before_compile,
      :script => <<-'SCRIPT'
        # Parse package_config.json to find plugin path
        PACKAGE_CONFIG="${SRCROOT}/../../.dart_tool/package_config.json"
        if [ ! -f "$PACKAGE_CONFIG" ]; then
          echo "Error: package_config.json not found"
          exit 1
        fi

        # Extract flutter_lmdb2 path using jq or grep/sed
        if command -v jq >/dev/null; then
          PLUGIN_ROOT=$(jq -r '.packages[] | select(.name == "flutter_lmdb2") | .rootUri' "$PACKAGE_CONFIG" | sed 's/file:\/\///')
        else
          PLUGIN_ROOT=$(grep -A 2 '"name":"flutter_lmdb2"' "$PACKAGE_CONFIG" | grep rootUri | cut -d '"' -f 4 | sed 's/file:\/\///')
        fi

        if [ -z "$PLUGIN_ROOT" ]; then
          echo "Error: Could not find flutter_lmdb2 in package_config.json"
          exit 1
        fi

        SOURCE_DIR="${PLUGIN_ROOT}/lib/src/native/macos"
        FRAMEWORK_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
        FRAMEWORK_LIBS="${FRAMEWORK_DIR}/Versions/A/Frameworks"

        echo "Directories:"
        echo "Source: ${SOURCE_DIR}"
        echo "Framework: ${FRAMEWORK_DIR}"
        echo "Framework Libs: ${FRAMEWORK_LIBS}"

        # Create framework directories
        mkdir -p "${FRAMEWORK_LIBS}"

        # Copy and sign the dylib
        cp -f "${SOURCE_DIR}/liblmdb.dylib" "${FRAMEWORK_LIBS}/"

        # Update install name and sign
        install_name_tool -id "@rpath/liblmdb.dylib" "${FRAMEWORK_LIBS}/liblmdb.dylib"
        codesign --force --sign - "${FRAMEWORK_LIBS}/liblmdb.dylib"

        # Sign the framework
        codesign --force --sign - --deep "${FRAMEWORK_DIR}"
      SCRIPT
    }

    s.dependency 'FlutterMacOS'
    s.platform = :osx, '10.13'

    s.pod_target_xcconfig = {
      'DEFINES_MODULE' => 'YES',
      'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited) @executable_path/../Frameworks'],
      'OTHER_LDFLAGS' => '-ObjC'
    }
end