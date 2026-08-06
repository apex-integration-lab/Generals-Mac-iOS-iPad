# frozen_string_literal: true

require "cfpropertylist"
require "open3"
require "openssl"

# GeneralsX @bugfix Codex 06/08/2026 Resolve Match signing identities by certificate hash.
module GeneralsXSigningIdentity
  Error = Class.new(StandardError)
  Identity = Struct.new(:certificate_hash, :name, keyword_init: true)

  module_function

  def resolve_codesign_identity(profile_plist, certificate_name:, identities_output: nil)
    profile_hashes = profile_certificate_hashes(profile_plist)
    raise Error, "No DeveloperCertificates found in #{profile_plist}" if profile_hashes.empty?

    identities_output ||= installed_identities_output
    identities = parse_code_signing_identities(identities_output)
    selected = select_identity_hash(profile_hashes, identities, certificate_name)
    return selected if selected

    expected = profile_hashes.join(", ")
    raise Error,
          "No installed code signing identity matches #{certificate_name.inspect} " \
          "and provisioning profile certificate hash(es): #{expected}"
  end

  def profile_certificate_hashes(profile_plist)
    plist = CFPropertyList::List.new(file: profile_plist)
    value = CFPropertyList.native_types(plist.value)
    certificates = value.fetch("DeveloperCertificates", [])
    certificates.map do |certificate|
      OpenSSL::Digest::SHA1.hexdigest(certificate.to_str).upcase
    end
  end

  def parse_code_signing_identities(output)
    output.each_line.filter_map do |line|
      match = line.match(/^\s*\d+\)\s+([0-9A-Fa-f]{40})\s+"([^"]+)"/)
      next unless match

      Identity.new(certificate_hash: match[1].upcase, name: match[2])
    end
  end

  def select_identity_hash(profile_hashes, identities, certificate_name)
    normalized_profile_hashes = profile_hashes.map(&:upcase)
    normalized_profile_hashes.each do |profile_hash|
      exact_name_match = identities.find do |identity|
        identity.certificate_hash == profile_hash && identity.name == certificate_name
      end
      return exact_name_match.certificate_hash if exact_name_match

      profile_match = identities.find { |identity| identity.certificate_hash == profile_hash }
      return profile_match.certificate_hash if profile_match
    end

    nil
  end

  def installed_identities_output
    output, status = Open3.capture2e("security", "find-identity", "-v", "-p", "codesigning")
    raise Error, "security find-identity failed:\n#{output}" unless status.success?

    output
  end
end
