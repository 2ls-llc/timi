# frozen_string_literal: true

cask "timi" do
  version "0.1.0"
  sha256 "REPLACE"

  url "https://github.com/2ls-llc/timi/releases/download/v#{version}/Timi-#{version}.zip"
  name "Timi"
  desc "Pixel cat that lives on your desktop and keeps your focus timer"
  homepage "https://github.com/2ls-llc/timi"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Timi.app"

  zap trash: [
    "~/Library/Application Support/Timi",
    "~/Library/Containers/com.2ls.timi",
    "~/Library/Preferences/com.2ls.timi.plist",
  ]

  caveats <<~EOS
    Timi isn't notarized by Apple yet, so macOS blocks her first launch.
    Open Timi once and click Done, then go to
      System Settings > Privacy & Security
    and click "Open Anyway". Each update needs this once more until
    releases are signed.
  EOS
end
