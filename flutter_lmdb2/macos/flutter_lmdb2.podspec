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

       echo "Plugin Root: $PLUGIN_ROOT"

       SOURCE_DIR="${PLUGIN_ROOT}/lib/src/native/macos"
       #APP_FRAMEWORKS="${TARGET_BUILD_DIR}/${PRODUCT_NAME}.app/Contents/Frameworks"
       APP_FRAMEWORKS="${HOST_TARGET_BUILD_DIR}/${PRODUCT_NAME}.app/Contents/Frameworks"

       echo "Source directory: ${SOURCE_DIR}"
       echo "APP_FRAMEWORKS directory: ${APP_FRAMEWORKS}"

       # Create Frameworks directory if it doesn't exist
       mkdir -p "${APP_FRAMEWORKS}"

       if [ -d "${SOURCE_DIR}" ]; then
         echo "Copying native libraries..."
         cp -R "${SOURCE_DIR}/liblmdb.dylib" "${APP_FRAMEWORKS}/"
         if [ $? -eq 0 ]; then
           echo "Successfully copied liblmdb.dylib"
           install_name_tool -id "@rpath/liblmdb.dylib" "${APP_FRAMEWORKS}/liblmdb.dylib"
           if [ $? -eq 0 ]; then
             echo "Successfully updated install name"
             # Verify the changes
             otool -L "${APP_FRAMEWORKS}/liblmdb.dylib"
           else
             echo "Failed to update install name"
             exit 1
           fi
         else
           echo "Failed to copy liblmdb.dylib"
           exit 1
         fi
       else
         echo "Warning: Source directory not found: ${SOURCE_DIR}"
         exit 1
       fi
     SCRIPT
   }

end