cask "pixel-pal" do
  version "0.1.0"
  sha256 "REPLACE"

  url "https://github.com/msull92/pixel-pal/releases/download/v#{version}/PixelPal-#{version}.zip"
  name "Pixel Pal"
  desc "A pixel pet that lives on your desktop and keeps your focus timer"
  homepage "https://github.com/msull92/pixel-pal"

  depends_on macos: ">= :sonoma"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "PixelPal.app"

  zap trash: [
    "~/Library/Preferences/com.msull92.pixelpal.plist",
    "~/Library/Application Support/PixelPal",
    "~/Library/Containers/com.msull92.pixelpal",
  ]
end
