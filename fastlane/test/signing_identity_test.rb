# frozen_string_literal: true

require "base64"
require "openssl"
require "tmpdir"

require_relative "../signing_identity"

def test_resolves_profile_certificate_hash_when_common_name_is_duplicated
  profile_hash = "F4167191D8F3004436258D23FAC6EB244360D438"
  identities_output = <<~TEXT
      1) 980CDB6B4317C6E7B545C3DC1C7340F2C7548C1F "Apple Distribution: Aaron Srivastava (LMFTNJ7TE4)"
      2) #{profile_hash} "Apple Distribution: Aaron Srivastava (LMFTNJ7TE4)"
         2 valid identities found
  TEXT

  Dir.mktmpdir do |dir|
    profile = File.join(dir, "profile.plist")
    write_profile_plist(profile, "profile certificate")

    expected_hash = OpenSSL::Digest::SHA1.hexdigest("profile certificate").upcase
    identities_output.sub!(profile_hash, expected_hash)

    assert_equal(
      expected_hash,
      GeneralsXSigningIdentity.resolve_codesign_identity(
        profile,
        certificate_name: "Apple Distribution: Aaron Srivastava (LMFTNJ7TE4)",
        identities_output: identities_output,
      ),
    )
  end
end

def test_errors_when_profile_certificate_is_not_in_keychain
  identities_output = <<~TEXT
      1) 980CDB6B4317C6E7B545C3DC1C7340F2C7548C1F "Apple Distribution: Aaron Srivastava (LMFTNJ7TE4)"
         1 valid identities found
  TEXT

  Dir.mktmpdir do |dir|
    profile = File.join(dir, "profile.plist")
    write_profile_plist(profile, "different certificate")

    error = assert_raises(GeneralsXSigningIdentity::Error) do
      GeneralsXSigningIdentity.resolve_codesign_identity(
        profile,
        certificate_name: "Apple Distribution: Aaron Srivastava (LMFTNJ7TE4)",
        identities_output: identities_output,
      )
    end

    assert_match(/No installed code signing identity matches/, error.message)
  end
end

def write_profile_plist(path, certificate_bytes)
  encoded = Base64.strict_encode64(certificate_bytes)
  File.write(path, <<~XML)
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
      "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>DeveloperCertificates</key>
      <array>
        <data>#{encoded}</data>
      </array>
    </dict>
    </plist>
  XML
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

test_resolves_profile_certificate_hash_when_common_name_is_duplicated
test_errors_when_profile_certificate_is_not_in_keychain

puts "signing_identity_test: ok"
