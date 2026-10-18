# frozen_string_literal: true

cask "timi" do
  version "0.1.0"
  sha256 "REPLACE"

  url "https://github.com/2ls-llc/timi/releases/download/v#{version}/Timi-#{version}.zip"
  name "Timi"
  desc "Pixel cat on your desktop that runs a focus timer"
  homepage "https://github.com/2ls-llc/timi"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Timi.app"

  zap trash: [
    "~/Library/Application Support/Timi",
    "~/Library/Containers/com.2ls.timi",
    "~/Library/Preferences/com.2ls.timi.plist",
  ]

  caveats <<~EOS
    Apple did not notarize this build, so macOS blocks Timi the first time
    you open her. To open Timi:
      1. Open Timi from your Applications folder.
      2. When macOS shows an alert, click Done.
      3. Open System Settings > Privacy & Security.
      4. Find the message about Timi.
      5. Click Open Anyway.
      6. If macOS asks for your password, enter it.
    You must do these steps again after each update, until we sign and
    notarize the releases.
  EOS
end
