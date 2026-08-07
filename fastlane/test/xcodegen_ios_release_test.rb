# frozen_string_literal: true

require "yaml"

SPEC_PATH = File.expand_path("../../ios/project.yml", __dir__)

def test_ios_target_declares_bluetooth_purpose_string
  properties = ios_target.fetch("info").fetch("properties")

  assert_match(/Bluetooth/, properties.fetch("NSBluetoothAlwaysUsageDescription"))
end

def test_ios_target_does_not_fabricate_swift_support
  settings = ios_target.fetch("settings").fetch("base")

  assert(!settings.key?("ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES"))
  assert(!File.exist?(File.expand_path("../../ios/Stub/SwiftSupportAnchor.swift", __dir__)))
end

def test_ios_target_stages_runtime_before_codesign
  scripts = ios_target.fetch("postBuildScripts")
  stage_script = scripts.find { |script| script.fetch("name") == "Stage GeneralsX runtime" }

  raise "Expected Stage GeneralsX runtime postBuildScript" unless stage_script

  script = stage_script.fetch("script")
  assert_match(/GX_CMAKE_BUILD_DIR/, script)
  assert_match(/GeneralsXZH\.app\/GeneralsXZH/, script)
  assert_match(/MoltenVK\.framework/, script)
  assert_match(/cp -f/, script)
  assert(!script.match?(/swift-stdlib-tool/))
  assert_match(/EXPANDED_CODE_SIGN_IDENTITY/, script)
  assert_match(/codesign/, script)
end

def test_ios_target_frameworkizes_non_swift_runtime_dylibs
  scripts = ios_target.fetch("postBuildScripts")
  stage_script = scripts.find { |script| script.fetch("name") == "Stage GeneralsX runtime" }

  raise "Expected Stage GeneralsX runtime postBuildScript" unless stage_script

  script = stage_script.fetch("script")
  assert_match(/package_runtime_framework/, script)
  assert_match(/SDL3\.framework\/SDL3/, script)
  assert_match(/DXVKD3D8\.framework\/DXVKD3D8/, script)
  refute_match(%r{\$\{FRAMEWORKS_DIR\}/libSDL3\.0\.dylib}, script)
  refute_match(%r{\$\{FRAMEWORKS_DIR\}/libdxvk_d3d8\.0\.dylib}, script)
end

def test_ios_target_regenerates_dsym_for_staged_engine
  scripts = ios_target.fetch("postBuildScripts")
  stage_script = scripts.find { |script| script.fetch("name") == "Stage GeneralsX runtime" }

  raise "Expected Stage GeneralsX runtime postBuildScript" unless stage_script

  script = stage_script.fetch("script")
  engine_copy_index = script.index('copy_required "${ENGINE_BIN}" "${APP_DIR}/${EXECUTABLE_NAME}"')
  dsymutil_index = script.index('dsymutil "${APP_DIR}/${EXECUTABLE_NAME}"')

  raise "Expected the engine executable to be staged" unless engine_copy_index
  raise "Expected dsymutil to regenerate symbols for the staged engine" unless dsymutil_index

  assert(engine_copy_index < dsymutil_index)
  assert_match(/DWARF_DSYM_FOLDER_PATH/, script)
  assert_match(/DWARF_DSYM_FILE_NAME/, script)
end

def test_ios_target_preserves_staged_engine_allocator_exports
  settings = ios_target.fetch("settings").fetch("base")

  assert_equal(false, settings.fetch("STRIP_INSTALLED_PRODUCT"))
end

def ios_target
  YAML.load_file(SPEC_PATH).fetch("targets").fetch("GeneralsXZH")
end

def assert_match(pattern, actual)
  raise "Expected #{actual.inspect} to match #{pattern.inspect}" unless actual.match?(pattern)
end

def assert(value)
  raise "Expected condition to be true" unless value
end

def refute_match(pattern, actual)
  raise "Expected #{actual.inspect} not to match #{pattern.inspect}" if actual.match?(pattern)
end

def assert_equal(expected, actual)
  raise "Expected #{expected.inspect}, got #{actual.inspect}" unless expected == actual
end

test_ios_target_declares_bluetooth_purpose_string
test_ios_target_does_not_fabricate_swift_support
test_ios_target_stages_runtime_before_codesign
test_ios_target_frameworkizes_non_swift_runtime_dylibs
test_ios_target_regenerates_dsym_for_staged_engine
test_ios_target_preserves_staged_engine_allocator_exports

puts "xcodegen_ios_release_test: ok"
