# frozen_string_literal: true

require "yaml"

SPEC_PATH = File.expand_path("../../ios/project.yml", __dir__)

def test_ios_target_declares_bluetooth_purpose_string
  properties = ios_target.fetch("info").fetch("properties")

  assert_match(/Bluetooth/, properties.fetch("NSBluetoothAlwaysUsageDescription"))
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
  assert_match(/EXPANDED_CODE_SIGN_IDENTITY/, script)
  assert_match(/codesign/, script)
end

def ios_target
  YAML.load_file(SPEC_PATH).fetch("targets").fetch("GeneralsXZH")
end

def assert_match(pattern, actual)
  raise "Expected #{actual.inspect} to match #{pattern.inspect}" unless actual.match?(pattern)
end

test_ios_target_declares_bluetooth_purpose_string
test_ios_target_stages_runtime_before_codesign

puts "xcodegen_ios_release_test: ok"
