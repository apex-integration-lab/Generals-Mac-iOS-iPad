# frozen_string_literal: true

require "json"

REPO_ROOT = File.expand_path("../..", __dir__)

def test_ios_simulator_preset_targets_simulator_sdk
  presets = JSON.parse(File.read(File.join(REPO_ROOT, "CMakePresets.json")))
  preset = presets.fetch("configurePresets").find { |item| item.fetch("name") == "ios-simulator" }

  raise "Expected ios-simulator configure preset" unless preset

  variables = preset.fetch("cacheVariables")
  assert_equal("iphonesimulator", variables.fetch("CMAKE_OSX_SYSROOT"))
  assert_equal("arm64-ios-simulator", variables.fetch("VCPKG_TARGET_TRIPLET"))
  assert_match(%r{/ios-arm64_x86_64-simulator/libMoltenVK\.a$}, variables.fetch("Vulkan_LIBRARY"))
end

def test_ios_simulator_triplet_pins_sdk_and_deployment_target
  triplet = File.read(File.join(REPO_ROOT, "cmake/triplets/arm64-ios-simulator.cmake"))

  assert_match(/VCPKG_OSX_SYSROOT iphonesimulator/, triplet)
  assert_match(/VCPKG_OSX_DEPLOYMENT_TARGET "16\.0"/, triplet)
end

def test_ios_meson_cross_file_uses_configured_sdk_and_deployment_flag
  template = File.read(File.join(REPO_ROOT, "cmake/meson-arm64-ios-cross.ini.in"))

  assert_match(/@IOS_SDK@/, template)
  assert_match(/@IOS_DEPLOYMENT_FLAG@/, template)
  refute_match(/-miphoneos-version-min=/, template)
end

def test_simulator_runner_builds_installs_and_launches
  runner = File.read(File.join(REPO_ROOT, "scripts/build/ios/run-ios-simulator-zh.sh"))

  assert_match(/cmake --preset ios-simulator/, runner)
  assert_match(%r{ninja -C "\$\{BUILD_DIR\}/_deps/dxvk-build-macos"}, runner)
  assert_match(/simctl list devices available.*tail -1/, runner)
  assert_match(/GX_GAME_DATA/, runner)
  assert_match(/GameData/, runner)
  assert_match(/xcrun simctl install/, runner)
  assert_match(/SIMCTL_CHILD_ALSOFT_DRIVERS=null/, runner)
  assert_match(/xcrun simctl launch --console-pty/, runner)
end

def test_dxvk_loads_the_embedded_sdl_framework_on_ios
  loader = File.read(File.join(REPO_ROOT, "references/fbraz3-dxvk/src/wsi/sdl3/wsi_platform_sdl3.cpp"))

  assert_match(/TARGET_OS_IPHONE/, loader)
  assert_match(%r{@rpath/SDL3\.framework/SDL3}, loader)
end

def test_dxvk_reuses_statically_linked_moltenvk_without_null_call
  loader = File.read(File.join(REPO_ROOT, "references/fbraz3-dxvk/src/vulkan/vulkan_loader.cpp"))

  assert_match(/dlsym\(RTLD_DEFAULT, "vkGetInstanceProcAddr"\)/, loader)
  assert_match(/if \(!m_getInstanceProcAddr\)\s+return nullptr;/, loader)
end

def test_ios_dxvk_patch_tracks_local_fork_runtime_fixes
  patch = File.read(File.join(REPO_ROOT, "Patches/dxvk-ios.patch"))

  assert_match(/dlsym\(RTLD_DEFAULT, "vkGetInstanceProcAddr"\)/, patch)
  assert_match(%r{@rpath/SDL3\.framework/SDL3}, patch)
end

def test_ios_packaging_removes_host_build_runpaths
  project = File.read(File.join(REPO_ROOT, "ios/project.yml"))

  assert_match(/remove_build_rpath/, project)
  assert_match(/-delete_rpath/, project)
  assert_match(%r{_deps/sdl3-build}, project)
  assert_match(%r{_deps/openal_soft-build}, project)
end

def test_game_memory_exports_modern_sized_delete_overloads
  implementation = File.read(
    File.join(REPO_ROOT, "Core/GameEngine/Source/Common/System/GameMemory.cpp"),
  )

  assert_match(/void operator delete\(void \*p, size_t\)/, implementation)
  assert_match(/void operator delete\[\]\(void \*p, size_t\)/, implementation)
end

def assert_match(pattern, actual)
  raise "Expected #{actual.inspect} to match #{pattern.inspect}" unless actual.match?(pattern)
end

def refute_match(pattern, actual)
  raise "Expected #{actual.inspect} not to match #{pattern.inspect}" if actual.match?(pattern)
end

def assert_equal(expected, actual)
  raise "Expected #{expected.inspect}, got #{actual.inspect}" unless expected == actual
end

test_ios_simulator_preset_targets_simulator_sdk
test_ios_simulator_triplet_pins_sdk_and_deployment_target
test_ios_meson_cross_file_uses_configured_sdk_and_deployment_flag
test_simulator_runner_builds_installs_and_launches
test_dxvk_loads_the_embedded_sdl_framework_on_ios
test_dxvk_reuses_statically_linked_moltenvk_without_null_call
test_ios_dxvk_patch_tracks_local_fork_runtime_fixes
test_ios_packaging_removes_host_build_runpaths
test_game_memory_exports_modern_sized_delete_overloads

puts "ios_simulator_build_test: ok"
