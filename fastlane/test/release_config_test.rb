# frozen_string_literal: true

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
  assert_equal("app-store", options.fetch(:export_method))
  assert_equal("GeneralsXZH.ipa", options.fetch(:output_name))

  export_options = options.fetch(:export_options)
  assert_equal("app-store", export_options.fetch(:method))
  assert_equal("manual", export_options.fetch(:signingStyle))
  assert_equal("LMFTNJ7TE4", export_options.fetch(:teamID))
  assert_equal("Apple Distribution", export_options.fetch(:signingCertificate))
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

def assert_equal(expected, actual)
  raise "Expected #{expected.inspect}, got #{actual.inspect}" unless expected == actual
end

def assert_match(pattern, actual)
  raise "Expected #{actual.inspect} to match #{pattern.inspect}" unless actual.match?(pattern)
end

test_match_options_install_signing_assets_into_fastlane_keychain
test_build_app_options_archive_and_export_app_store_ipa

puts "release_config_test: ok"
