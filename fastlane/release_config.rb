# frozen_string_literal: true

require "base64"
require "open3"
require "shellwords"
require "tmpdir"

# GeneralsX @build Codex 06/08/2026 Centralize Fastlane iOS release build options.
module GeneralsXReleaseConfig
  Error = Class.new(StandardError)

  DEFAULT_KEYCHAIN_NAME = "generalsx-ios-release.keychain"
  DEFAULT_KEYCHAIN_PASSWORD = "generalsx-ios-release"

  module_function

  def keychain_name(env = ENV)
    env.fetch("GX_MATCH_KEYCHAIN_NAME", DEFAULT_KEYCHAIN_NAME)
  end

  def keychain_password(env = ENV)
    env.fetch("GX_MATCH_KEYCHAIN_PASSWORD", DEFAULT_KEYCHAIN_PASSWORD)
  end

  def app_store_connect_api_key_options(env = ENV)
    key_id = first_env_value(env, "APP_STORE_CONNECT_API_KEY_ID", "APP_STORE_CONNECT_KEY_ID")
    issuer_id = first_env_value(env, "APP_STORE_CONNECT_ISSUER_ID")
    key_content = first_env_value(env, "APP_STORE_CONNECT_API_KEY_BASE64", "APP_STORE_CONNECT_KEY_BASE64")
    key_path = first_env_value(env, "APP_STORE_CONNECT_KEY_PATH")
    key_content ||= Base64.strict_encode64(File.binread(key_path)) if key_path && File.file?(key_path)

    missing = []
    missing << "APP_STORE_CONNECT_API_KEY_ID or APP_STORE_CONNECT_KEY_ID" unless key_id
    missing << "APP_STORE_CONNECT_ISSUER_ID" unless issuer_id
    unless key_content
      missing << "APP_STORE_CONNECT_API_KEY_BASE64, APP_STORE_CONNECT_KEY_BASE64, or APP_STORE_CONNECT_KEY_PATH"
    end
    raise Error, "Missing App Store Connect API-key secrets: #{missing.join(', ')}" unless missing.empty?

    {
      key_id: key_id,
      issuer_id: issuer_id,
      key_content: key_content,
      is_key_content_base64: true,
    }
  end

  def apply_ios_build_defaults!(env = ENV, home: Dir.home, now: Time.now.utc)
    vcpkg_root = File.join(home, "vcpkg")
    env["VCPKG_ROOT"] = vcpkg_root if !env_value?(env, "VCPKG_ROOT") && Dir.exist?(vcpkg_root)

    vulkan_sdk = latest_vulkan_sdk(home)
    env["VULKAN_SDK"] = vulkan_sdk if !env_value?(env, "VULKAN_SDK") && vulkan_sdk
    env["GX_BUILD_NUMBER"] = now.utc.strftime("%Y%m%d%H%M") unless env_value?(env, "GX_BUILD_NUMBER")
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
      export_team_id: team_id,
      include_bitcode: false,
      include_symbols: true,
      export_options: {
        # GeneralsX @build Codex 06/08/2026 Use Xcode's current App Store Connect export method.
        method: "app-store-connect",
        signingStyle: "manual",
        teamID: team_id,
        signingCertificate: certificate_name,
        uploadSymbols: true,
        uploadBitcode: false,
        stripSwiftSymbols: true,
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

  def testflight_upload_options(ipa:, default_group:, env: ENV)
    options = {
      ipa: ipa,
      skip_waiting_for_build_processing: false,
    }
    unless env.fetch("GX_TESTFLIGHT_SUBMIT", "false") == "true"
      options[:skip_submission] = true
      return options
    end

    groups = first_env_value(env, "GX_TESTFLIGHT_GROUPS")
    groups = groups ? groups.split(",").map(&:strip).reject(&:empty?) : [default_group]
    options.merge(
      groups: groups,
      distribute_external: env.fetch("GX_TESTFLIGHT_EXTERNAL", "false") == "true",
      skip_submission: false,
    )
  end

  def xcodebuild_settings(settings)
    settings.map { |key, value| "#{key}=#{value.to_s.shellescape}" }.join(" ")
  end

  def latest_vulkan_sdk(home)
    candidates = Dir.glob(File.join(home, "VulkanSDK", "*", "macOS")).select { |path| File.directory?(path) }
    candidates.max_by { |path| version_key(File.basename(File.dirname(path))) }
  end

  def version_key(version)
    version.split(".").map { |part| part.to_i }
  end

  def first_env_value(env, *keys)
    keys.each do |key|
      return env[key] if env_value?(env, key)
    end
    nil
  end

  def env_value?(env, key)
    value = env[key]
    value && !value.empty?
  end

  def validate_ipa_swift_support!(ipa_path, entries: nil, engine_load_commands: nil)
    entries ||= ipa_entries(ipa_path)
    standalone_dylibs = non_swift_standalone_dylibs(entries)
    engine_load_commands ||= ipa_engine_load_commands(ipa_path, entries)
    packaged_swift_core = entries.any? do |entry|
      entry.end_with?("/libswiftCore.dylib")
    end
    legacy_swift_load = engine_load_commands.any? { |command| command.include?("@rpath/libswiftCore.dylib") }

    issues = []
    issues << "iOS 16 apps must not package libswiftCore.dylib" if packaged_swift_core || legacy_swift_load
    unless standalone_dylibs.empty?
      issues << "standalone runtime dylibs must be framework bundles: #{standalone_dylibs.join(', ')}"
    end
    return true if issues.empty?

    raise Error, "IPA #{ipa_path} has invalid iOS runtime packaging: #{issues.join('; ')}"
  end

  def validate_archive_dsym!(archive_path, app_name:, uuid_reader: nil)
    app_binary = File.join(
      archive_path,
      "Products",
      "Applications",
      "#{app_name}.app",
      app_name,
    )
    dsym_binary = File.join(
      archive_path,
      "dSYMs",
      "#{app_name}.app.dSYM",
      "Contents",
      "Resources",
      "DWARF",
      app_name,
    )
    raise Error, "Archive app executable is missing: #{app_binary}" unless File.file?(app_binary)
    raise Error, "Archive dSYM is missing: #{dsym_binary}" unless File.file?(dsym_binary)

    uuid_reader ||= method(:dwarf_uuids)
    app_uuids = uuid_reader.call(app_binary).map(&:upcase)
    dsym_uuids = uuid_reader.call(dsym_binary).map(&:upcase)
    missing_uuids = app_uuids - dsym_uuids
    return true if !app_uuids.empty? && missing_uuids.empty?

    raise Error,
          "Archive dSYM does not match app UUID(s): " \
          "app=#{app_uuids.join(',')} dSYM=#{dsym_uuids.join(',')}"
  end

  def dwarf_uuids(binary_path)
    output, status = Open3.capture2e("dwarfdump", "--uuid", binary_path)
    raise Error, "Unable to inspect UUID for #{binary_path}: #{output.strip}" unless status.success?

    output.scan(/UUID:\s+([0-9A-F-]+)/i).flatten
  end

  def ipa_entries(ipa_path)
    output, status = Open3.capture2e("unzip", "-Z1", ipa_path)
    return output.lines.map(&:chomp) if status.success?

    raise Error, "Unable to inspect IPA #{ipa_path}: #{output.strip}"
  end

  def ipa_engine_load_commands(ipa_path, entries)
    app_info = entries.find { |entry| entry.match?(%r{\APayload/[^/]+\.app/Info\.plist\z}) }
    raise Error, "Unable to locate app Info.plist in #{ipa_path}" unless app_info

    app_dir = app_info.sub(%r{\APayload/}, "").sub(%r{/Info\.plist\z}, "")
    executable = File.basename(app_dir, ".app")
    executable_entry = "Payload/#{app_dir}/#{executable}"
    raise Error, "Unable to locate app executable #{executable_entry} in #{ipa_path}" unless entries.include?(executable_entry)

    Dir.mktmpdir("generalsx-ipa-") do |dir|
      executable_path = File.join(dir, executable)
      executable_data, unzip_status = Open3.capture2("unzip", "-p", ipa_path, executable_entry)
      raise Error, "Unable to extract #{executable_entry} from #{ipa_path}" unless unzip_status.success?

      File.binwrite(executable_path, executable_data)
      output, otool_status = Open3.capture2e("otool", "-L", executable_path)
      raise Error, "Unable to inspect #{executable_entry}: #{output.strip}" unless otool_status.success?

      output.lines.map(&:strip)
    end
  end

  def non_swift_standalone_dylibs(entries)
    entries.select do |entry|
      next false unless entry.match?(%r{\APayload/[^/]+\.app/.+\.dylib\z})
      next false if File.basename(entry).start_with?("libswift")

      !entry.match?(%r{\APayload/[^/]+\.app/Frameworks/[^/]+\.framework/})
    end
  end
end
