#
# Generated file - DO NOT EDIT
# This file filters out plugins that are not supported on Windows
#

# Include the generated plugins
include(${CMAKE_CURRENT_LIST_DIR}/generated_plugins.cmake)

# Filter out flutter_sound which is not supported on Windows
# flutter_sound supports: Android, iOS, macOS, Linux, Web but NOT Windows
if(DEFINED FLUTTER_PLUGIN_LIST)
  list(REMOVE_ITEM FLUTTER_PLUGIN_LIST flutter_sound)
endif()

if(DEFINED PLUGIN_BUNDLED_LIBRARIES)
  # Remove any flutter_sound libraries from the bundle list
  list(FILTER PLUGIN_BUNDLED_LIBRARIES EXCLUDE REGEX "flutter_sound")
endif()
