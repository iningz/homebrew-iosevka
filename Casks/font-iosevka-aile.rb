cask "font-iosevka-aile" do
  version "34.6.3"
  sha256 "74e52eea7724732f6366f2f131c74349acb47ca5463884692c8bd90c18b120d5"

  url "https://github.com/be5invis/Iosevka/releases/download/v#{version}/PkgTTF-Unhinted-IosevkaAile-#{version}.zip"
  name "Iosevka Aile"
  homepage "https://typeof.net/Iosevka/"

  font "IosevkaAile-*.ttf"
end
