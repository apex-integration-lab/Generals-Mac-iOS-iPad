# frozen_string_literal: true

require_relative "../upload_auth"

def test_apple_id_auth_errors_before_upload_without_app_specific_password
  env = {
    "GX_USE_APPLE_ID_AUTH" => "true",
  }

  error = assert_raises(GeneralsXUploadAuth::Error) do
    GeneralsXUploadAuth.validate_apple_id_upload_env!(env)
  end

  assert_match(/FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD/, error.message)
  assert_match(/GX_APPLE_ID/, error.message)
end

def test_apple_id_upload_options_are_upload_only
  env = {
    "GX_USE_APPLE_ID_AUTH" => "true",
    "FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD" => "app-password",
    "FASTLANE_USER" => "aaron@example.com",
    "GX_APPLE_ID" => "6798353282",
    "GX_ITC_PROVIDER" => "provider",
  }
  base_options = {
    ipa: "build/ios-package/GeneralsXZH.ipa",
    groups: ["Aaron"],
    distribute_external: false,
    skip_waiting_for_build_processing: false,
  }

  options = GeneralsXUploadAuth.apple_id_upload_options(
    base_options,
    bundle_id: "com.aaron.generalszh",
    env: env,
  )

  assert_equal("build/ios-package/GeneralsXZH.ipa", options.fetch(:ipa))
  assert_equal("com.aaron.generalszh", options.fetch(:app_identifier))
  assert_equal("6798353282", options.fetch(:apple_id))
  assert_equal("aaron@example.com", options.fetch(:username))
  assert_equal("provider", options.fetch(:itc_provider))
  assert_equal(true, options.fetch(:skip_waiting_for_build_processing))
  assert_equal(true, options.fetch(:skip_submission))
  assert_equal(false, options.key?(:groups))
  assert_equal(false, options.key?(:distribute_external))
end

def test_apple_id_upload_options_can_use_configured_app_store_app_id
  env = {
    "GX_USE_APPLE_ID_AUTH" => "true",
    "FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD" => "app-password",
  }
  base_options = {
    ipa: "build/ios-package/GeneralsXZH.ipa",
    groups: ["Aaron"],
    distribute_external: false,
    skip_waiting_for_build_processing: false,
  }

  options = GeneralsXUploadAuth.apple_id_upload_options(
    base_options,
    bundle_id: "com.aaron.generalszh",
    fallback_apple_id: "6798353282",
    env: env,
  )

  assert_equal("6798353282", options.fetch(:apple_id))
end

def test_empty_apple_id_env_uses_configured_app_store_app_id
  env = {
    "GX_USE_APPLE_ID_AUTH" => "true",
    "FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD" => "app-password",
    "GX_APPLE_ID" => "",
  }
  base_options = {
    ipa: "build/ios-package/GeneralsXZH.ipa",
  }

  options = GeneralsXUploadAuth.apple_id_upload_options(
    base_options,
    bundle_id: "com.aaron.generalszh",
    fallback_apple_id: "6798353282",
    env: env,
  )

  assert_equal("6798353282", options.fetch(:apple_id))
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

test_apple_id_auth_errors_before_upload_without_app_specific_password
test_apple_id_upload_options_are_upload_only
test_apple_id_upload_options_can_use_configured_app_store_app_id
test_empty_apple_id_env_uses_configured_app_store_app_id

puts "upload_auth_test: ok"
