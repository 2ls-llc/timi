cask "timi" do
  version "0.1.0"
  sha256 "REPLACE"

  url "https://github.com/twols/timi/releases/download/v#{version}/Timi-#{version}.zip"
  name "Timi"
  desc "Pixel cat that lives on your desktop and keeps your focus timer"
  homepage "https://github.com/twols/timi"

  depends_on macos: ">= :sonoma"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Timi.app"

  zap trash: [
    "~/Library/Preferences/com.twols.timi.plist",
    "~/Library/Application Support/Timi",
    "~/Library/Containers/com.twols.timi",
  ]
end
