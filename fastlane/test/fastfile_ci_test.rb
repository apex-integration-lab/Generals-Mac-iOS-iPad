# frozen_string_literal: true

fastfile = File.read(File.expand_path("../Fastfile", __dir__))
beta_start = fastfile.index("lane :beta do")
submit_start = fastfile.index("desc \"Submit a processed TestFlight build", beta_start)
raise "Could not find beta lane" unless beta_start
raise "Could not find submit lane" unless submit_start

beta_lane = fastfile[beta_start...submit_start]

keychain_index = beta_lane.index("prepare_release_keychain")
match_index = beta_lane.index("sync_appstore_signing")
swift_support_validation_index = beta_lane.index("validate_ipa_swift_support!")
archive_dsym_validation_index = beta_lane.index("validate_archive_dsym!")
upload_index = beta_lane.index("upload_to_testflight")

raise "beta lane must prepare a dedicated release keychain" unless keychain_index
raise "beta lane must sync Match signing" unless match_index
raise "beta lane must validate IPA SwiftSupport before upload" unless swift_support_validation_index
raise "beta lane must validate the archive dSYM before upload" unless archive_dsym_validation_index
raise "Could not find TestFlight upload" unless upload_index
raise "release keychain must be prepared before Match signing sync" unless keychain_index < match_index
raise "IPA SwiftSupport validation must run before TestFlight upload" unless swift_support_validation_index < upload_index
raise "archive dSYM validation must run before TestFlight upload" unless archive_dsym_validation_index < upload_index

puts "fastfile_ci_test: ok"
