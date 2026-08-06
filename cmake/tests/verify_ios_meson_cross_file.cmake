if(NOT DEFINED CROSS_FILE)
  message(FATAL_ERROR "Set CROSS_FILE to the generated meson-arm64-ios-cross.ini path")
endif()

if(NOT DEFINED VULKAN_SDK_ROOT)
  message(FATAL_ERROR "Set VULKAN_SDK_ROOT to the LunarG Vulkan SDK macOS directory")
endif()

if(NOT EXISTS "${CROSS_FILE}")
  message(FATAL_ERROR "CROSS_FILE does not exist: ${CROSS_FILE}")
endif()

file(READ "${CROSS_FILE}" cross_file_contents)
set(expected_vulkan_include "-I${VULKAN_SDK_ROOT}/include")

foreach(arg_name IN ITEMS c_args cpp_args)
  string(REGEX MATCH "${arg_name} = \\[[^\n]*\\]" arg_line "${cross_file_contents}")
  if(NOT arg_line)
    message(FATAL_ERROR "${arg_name} was not found in ${CROSS_FILE}")
  endif()

  string(FIND "${arg_line}" "${expected_vulkan_include}" include_arg_index)
  if(include_arg_index EQUAL -1)
    message(FATAL_ERROR
      "${arg_name} must include ${expected_vulkan_include} so DXVK Meson checks can find vulkan/vulkan.h")
  endif()
endforeach()
