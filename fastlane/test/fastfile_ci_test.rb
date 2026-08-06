# frozen_string_literal: true

fastfile = File.read(File.expand_path("../Fastfile", __dir__))
beta_lane = fastfile.match(/lane :beta do(?<body>.*?)^\s+end/m)&.named_captures&.fetch("body")
raise "Could not find beta lane" unless beta_lane

keychain_index = beta_lane.index("prepare_release_keychain")
match_index = beta_lane.index("sync_appstore_signing")

raise "beta lane must prepare a dedicated release keychain" unless keychain_index
raise "beta lane must sync Match signing" unless match_index
raise "release keychain must be prepared before Match signing sync" unless keychain_index < match_index

puts "fastfile_ci_test: ok"
