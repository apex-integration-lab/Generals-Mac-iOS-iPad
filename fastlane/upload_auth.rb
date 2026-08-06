# frozen_string_literal: true

# GeneralsX @bugfix Codex 06/08/2026 Validate Apple ID TestFlight upload auth before building.
module GeneralsXUploadAuth
  Error = Class.new(StandardError)
  APPLE_ID_UPLOAD_REQUIRED_ENV = %w[
    FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD
    GX_APPLE_ID
  ].freeze

  module_function

  def apple_id_auth?(env = ENV)
    env.fetch("GX_USE_APPLE_ID_AUTH", "false") == "true"
  end

  def validate_apple_id_upload_env!(env = ENV, fallback_apple_id: nil)
    missing = APPLE_ID_UPLOAD_REQUIRED_ENV.reject { |key| env_value?(env, key) }
    missing.delete("GX_APPLE_ID") if fallback_apple_id.to_s != ""
    return if missing.empty?

    raise Error,
          "Apple ID TestFlight upload requires #{missing.join(', ')}. " \
          "Use App Store Connect API-key auth for automatic TestFlight processing " \
          "and internal group distribution."
  end

  def apple_id_upload_options(base_options, bundle_id:, fallback_apple_id: nil, env: ENV)
    validate_apple_id_upload_env!(env, fallback_apple_id: fallback_apple_id)

    options = base_options.dup
    options.delete(:groups)
    options.delete(:distribute_external)
    apple_id = env_value?(env, "GX_APPLE_ID") ? env.fetch("GX_APPLE_ID") : fallback_apple_id
    options.merge!(
      app_identifier: bundle_id,
      apple_id: apple_id,
      skip_submission: true,
      skip_waiting_for_build_processing: true,
    )

    options[:username] = env.fetch("FASTLANE_USER") if env_value?(env, "FASTLANE_USER")
    options[:itc_provider] = env.fetch("GX_ITC_PROVIDER") if env_value?(env, "GX_ITC_PROVIDER")
    options
  end

  def env_value?(env, key)
    value = env[key]
    value && !value.empty?
  end
end
