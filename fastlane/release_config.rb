# frozen_string_literal: true

require "shellwords"

# GeneralsX @build Codex 06/08/2026 Centralize Fastlane iOS release build options.
module GeneralsXReleaseConfig
  DEFAULT_KEYCHAIN_NAME = "generalsx-ios-release.keychain"
  DEFAULT_KEYCHAIN_PASSWORD = "generalsx-ios-release"

  module_function

  def keychain_name(env = ENV)
    env.fetch("GX_MATCH_KEYCHAIN_NAME", DEFAULT_KEYCHAIN_NAME)
  end

  def keychain_password(env = ENV)
    env.fetch("GX_MATCH_KEYCHAIN_PASSWORD", DEFAULT_KEYCHAIN_PASSWORD)
  end

  def match_options(bundle_id:, team_id:, keychain_name:, keychain_password:, api_key: nil)
    options = {
      type: "appstore",
      app_identifier: bundle_id,
      team_id: team_id,
      readonly: true,
      keychain_name: keychain_name,
      keychain_password: keychain_password,
    }
    options[:api_key] = api_key if api_key
    options
  end

  def build_app_options(app_name:, xcodeproj:, derived_data_path:, out_dir:, bundle_id:,
                        team_id:, profile_name:, certificate_name:, keychain_path:)
    {
      project: xcodeproj,
      scheme: app_name,
      configuration: "Release",
      destination: "generic/platform=iOS",
      derived_data_path: derived_data_path,
      archive_path: File.expand_path("#{out_dir}/#{app_name}.xcarchive"),
      output_directory: File.expand_path(out_dir),
      output_name: "#{app_name}.ipa",
      export_method: "app-store",
      export_team_id: team_id,
      include_bitcode: false,
      include_symbols: true,
      export_options: {
        method: "app-store",
        signingStyle: "manual",
        teamID: team_id,
        signingCertificate: certificate_name,
        provisioningProfiles: {
          bundle_id => profile_name,
        },
      },
      xcargs: xcodebuild_settings(
        "DEVELOPMENT_TEAM" => team_id,
        "PRODUCT_BUNDLE_IDENTIFIER" => bundle_id,
        "CODE_SIGN_STYLE" => "Manual",
        "PROVISIONING_PROFILE_SPECIFIER" => profile_name,
        "CODE_SIGN_IDENTITY" => certificate_name,
        "OTHER_CODE_SIGN_FLAGS" => "--keychain #{keychain_path}",
      ),
    }
  end

  def xcodebuild_settings(settings)
    settings.map { |key, value| "#{key}=#{value.to_s.shellescape}" }.join(" ")
  end
end
