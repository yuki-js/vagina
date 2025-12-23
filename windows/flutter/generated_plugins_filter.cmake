#
# Generated file, do not edit.
#
# This file filters the generated_plugins.cmake to exclude plugins that are not
# supported on this platform.

# Include the generated plugins
include(${CMAKE_CURRENT_LIST_DIR}/generated_plugins.cmake)

# Filter out flutter_sound which is not supported on Windows
# flutter_sound only supports: Android, iOS, macOS, Linux, Web
# See: https://pub.dev/packages/flutter_sound
if(DEFINED FLUTTER_PLUGIN_LIST)
  list(REMOVE_ITEM FLUTTER_PLUGIN_LIST flutter_sound)
endif()

if(DEFINED PLUGIN_BUNDLED_LIBRARIES)
  list(FILTER PLUGIN_BUNDLED_LIBRARIES EXCLUDE REGEX "flutter_sound")
endif()
