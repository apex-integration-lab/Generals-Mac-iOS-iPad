# frozen_string_literal: true

require "base64"
require "fileutils"
require_relative "../release_config"

def test_match_options_install_signing_assets_into_fastlane_keychain
  options = GeneralsXReleaseConfig.match_options(
    bundle_id: "com.aaron.generalszh",
    team_id: "LMFTNJ7TE4",
    keychain_name: "generalsx-test.keychain",
    keychain_password: "test-password",
  )

  assert_equal("appstore", options.fetch(:type))
  assert_equal("com.aaron.generalszh", options.fetch(:app_identifier))
  assert_equal("LMFTNJ7TE4", options.fetch(:team_id))
  assert_equal(true, options.fetch(:readonly))
  assert_equal("generalsx-test.keychain", options.fetch(:keychain_name))
  assert_equal("test-password", options.fetch(:keychain_password))
end

def test_build_app_options_archive_and_export_app_store_ipa
  options = GeneralsXReleaseConfig.build_app_options(
    app_name: "GeneralsXZH",
    xcodeproj: "/repo/ios/GeneralsXZH.xcodeproj",
    derived_data_path: "ios/build",
    out_dir: "build/ios-package",
    bundle_id: "com.aaron.generalszh",
    team_id: "LMFTNJ7TE4",
    profile_name: "match AppStore com.aaron.generalszh",
    certificate_name: "Apple Distribution",
    keychain_path: "/Users/example/Library/Keychains/generalsx-test.keychain-db",
  )

  assert_equal("/repo/ios/GeneralsXZH.xcodeproj", options.fetch(:project))
  assert_equal("GeneralsXZH", options.fetch(:scheme))
  assert_equal("Release", options.fetch(:configuration))
  assert_equal("generic/platform=iOS", options.fetch(:destination))
  assert_equal(false, options.key?(:export_method))
  assert_equal("GeneralsXZH.ipa", options.fetch(:output_name))

  export_options = options.fetch(:export_options)
  assert_equal("app-store-connect", export_options.fetch(:method))
  assert_equal("manual", export_options.fetch(:signingStyle))
  assert_equal("LMFTNJ7TE4", export_options.fetch(:teamID))
  assert_equal("Apple Distribution", export_options.fetch(:signingCertificate))
  assert_equal(true, export_options.fetch(:uploadSymbols))
  assert_equal(false, export_options.fetch(:uploadBitcode))
  assert_equal(true, export_options.fetch(:stripSwiftSymbols))
  assert_equal(
    { "com.aaron.generalszh" => "match AppStore com.aaron.generalszh" },
    export_options.fetch(:provisioningProfiles),
  )

  xcargs = options.fetch(:xcargs)
  assert_match(/PRODUCT_BUNDLE_IDENTIFIER=com\.aaron\.generalszh/, xcargs)
  assert_match(/PROVISIONING_PROFILE_SPECIFIER=match\\ AppStore\\ com\.aaron\.generalszh/, xcargs)
  assert_match(/CODE_SIGN_IDENTITY=Apple\\ Distribution/, xcargs)
  assert_match(%r{OTHER_CODE_SIGN_FLAGS=--keychain\\\s+/Users/example/Library/Keychains}, xcargs)
end

def test_app_store_connect_api_key_options_accept_short_env_names_and_key_path
  Dir.mktmpdir("generalsx-key-test-") do |dir|
    key_path = File.join(dir, "AuthKey_TEST.p8")
    File.binwrite(key_path, "private-key")

    options = GeneralsXReleaseConfig.app_store_connect_api_key_options(
      {
        "APP_STORE_CONNECT_KEY_ID" => "KEYID",
        "APP_STORE_CONNECT_ISSUER_ID" => "issuer-id",
        "APP_STORE_CONNECT_KEY_PATH" => key_path,
      },
    )

    assert_equal("KEYID", options.fetch(:key_id))
    assert_equal("issuer-id", options.fetch(:issuer_id))
    assert_equal(Base64.strict_encode64("private-key"), options.fetch(:key_content))
    assert_equal(true, options.fetch(:is_key_content_base64))
  end
end

def test_apply_ios_build_defaults_uses_local_tool_paths_and_timestamp_build_number
  Dir.mktmpdir("generalsx-home-") do |home|
    FileUtils.mkdir_p(File.join(home, "vcpkg"))
    FileUtils.mkdir_p(File.join(home, "VulkanSDK", "1.4.341.1", "macOS"))
    FileUtils.mkdir_p(File.join(home, "VulkanSDK", "1.4.400.0", "macOS"))
    env = {}

    GeneralsXReleaseConfig.apply_ios_build_defaults!(
      env,
      home: home,
      now: Time.utc(2026, 8, 6, 0, 45),
    )

    assert_equal(File.join(home, "vcpkg"), env.fetch("VCPKG_ROOT"))
    assert_equal(File.join(home, "VulkanSDK", "1.4.400.0", "macOS"), env.fetch("VULKAN_SDK"))
    assert_equal("202608060045", env.fetch("GX_BUILD_NUMBER"))
  end
end

def test_testflight_upload_options_default_to_upload_only
  options = GeneralsXReleaseConfig.testflight_upload_options(
    ipa: "build/ios-package/GeneralsXZH.ipa",
    default_group: "Aaron",
    env: {},
  )

  assert_equal("build/ios-package/GeneralsXZH.ipa", options.fetch(:ipa))
  assert_equal(false, options.fetch(:skip_waiting_for_build_processing))
  assert_equal(true, options.fetch(:skip_submission))
  assert_equal(false, options.key?(:groups))
  assert_equal(false, options.key?(:distribute_external))
end

def test_testflight_upload_options_can_submit_to_configured_groups
  options = GeneralsXReleaseConfig.testflight_upload_options(
    ipa: "build/ios-package/GeneralsXZH.ipa",
    default_group: "Aaron",
    env: {
      "GX_TESTFLIGHT_SUBMIT" => "true",
      "GX_TESTFLIGHT_GROUPS" => "Aaron, QA",
      "GX_TESTFLIGHT_EXTERNAL" => "true",
    },
  )

  assert_equal(["Aaron", "QA"], options.fetch(:groups))
  assert_equal(true, options.fetch(:distribute_external))
  assert_equal(false, options.fetch(:skip_submission))
end

def test_validate_ipa_swift_support_accepts_swift_free_app
  GeneralsXReleaseConfig.validate_ipa_swift_support!(
    "GeneralsXZH.ipa",
    entries: [],
    engine_load_commands: [
      "@rpath/SDL3.framework/SDL3",
    ],
  )
end

def test_validate_ipa_swift_support_rejects_fabricated_swift_runtime
  error = assert_raises(GeneralsXReleaseConfig::Error) do
    GeneralsXReleaseConfig.validate_ipa_swift_support!(
      "GeneralsXZH.ipa",
      entries: [
        "Payload/GeneralsXZH.app/Frameworks/libswiftCore.dylib",
        "SwiftSupport/iphoneos/libswiftCore.dylib",
      ],
      engine_load_commands: [
        "@rpath/libswiftCore.dylib",
      ],
    )
  end

  assert_match(/must not package libswiftCore\.dylib/, error.message)
end

def test_validate_ipa_swift_support_rejects_non_swift_standalone_dylibs
  error = assert_raises(GeneralsXReleaseConfig::Error) do
    GeneralsXReleaseConfig.validate_ipa_swift_support!(
      "GeneralsXZH.ipa",
      entries: [
        "Payload/GeneralsXZH.app/Frameworks/libSDL3.0.dylib",
      ],
      engine_load_commands: [
        "@rpath/libSDL3.0.dylib",
      ],
    )
  end

  assert_match(/standalone.*libSDL3\.0\.dylib/, error.message)
end

def test_validate_ipa_swift_support_accepts_system_swift_runtime
  GeneralsXReleaseConfig.validate_ipa_swift_support!(
    "GeneralsXZH.ipa",
    entries: [],
    engine_load_commands: [
      "/usr/lib/swift/libswiftCore.dylib",
    ],
  )
end

def test_validate_archive_dsym_accepts_matching_engine_symbols
  Dir.mktmpdir("generalsx-archive-test-") do |dir|
    app_binary = File.join(dir, "Products/Applications/GeneralsXZH.app/GeneralsXZH")
    dsym_binary = File.join(
      dir,
      "dSYMs/GeneralsXZH.app.dSYM/Contents/Resources/DWARF/GeneralsXZH",
    )
    FileUtils.mkdir_p(File.dirname(app_binary))
    FileUtils.mkdir_p(File.dirname(dsym_binary))
    FileUtils.touch(app_binary)
    FileUtils.touch(dsym_binary)

    GeneralsXReleaseConfig.validate_archive_dsym!(
      dir,
      app_name: "GeneralsXZH",
      uuid_reader: ->(_path) { ["446CEB0C-974F-39EA-8836-E3C80C0E9E68"] },
    )
  end
end

def test_validate_archive_dsym_rejects_stale_wrapper_symbols
  Dir.mktmpdir("generalsx-archive-test-") do |dir|
    app_binary = File.join(dir, "Products/Applications/GeneralsXZH.app/GeneralsXZH")
    dsym_binary = File.join(
      dir,
      "dSYMs/GeneralsXZH.app.dSYM/Contents/Resources/DWARF/GeneralsXZH",
    )
    FileUtils.mkdir_p(File.dirname(app_binary))
    FileUtils.mkdir_p(File.dirname(dsym_binary))
    FileUtils.touch(app_binary)
    FileUtils.touch(dsym_binary)

    error = assert_raises(GeneralsXReleaseConfig::Error) do
      GeneralsXReleaseConfig.validate_archive_dsym!(
        dir,
        app_name: "GeneralsXZH",
        uuid_reader: lambda do |path|
          if path == app_binary
            ["446CEB0C-974F-39EA-8836-E3C80C0E9E68"]
          else
            ["9F63ACA6-9423-3238-AD5A-4C7B7D588A89"]
          end
        end,
      )
    end

    assert_match(/does not match app UUID/, error.message)
  end
end

def assert_equal(expected, actual)
  raise "Expected #{expected.inspect}, got #{actual.inspect}" unless expected == actual
end

def assert_match(pattern, actual)
  raise "Expected #{actual.inspect} to match #{pattern.inspect}" unless actual.match?(pattern)
end

def assert_raises(expected_error)
  yield
  raise "Expected #{expected_error} to be raised"
rescue expected_error => error
  error
end

test_match_options_install_signing_assets_into_fastlane_keychain
test_build_app_options_archive_and_export_app_store_ipa
test_app_store_connect_api_key_options_accept_short_env_names_and_key_path
test_apply_ios_build_defaults_uses_local_tool_paths_and_timestamp_build_number
test_testflight_upload_options_default_to_upload_only
test_testflight_upload_options_can_submit_to_configured_groups
test_validate_ipa_swift_support_accepts_swift_free_app
test_validate_ipa_swift_support_rejects_fabricated_swift_runtime
test_validate_ipa_swift_support_rejects_non_swift_standalone_dylibs
test_validate_ipa_swift_support_accepts_system_swift_runtime
test_validate_archive_dsym_accepts_matching_engine_symbols
test_validate_archive_dsym_rejects_stale_wrapper_symbols

puts "release_config_test: ok"
