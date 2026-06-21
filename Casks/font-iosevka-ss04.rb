cask "font-iosevka-ss04" do
  version "34.6.3"
  sha256 "54a194a4ea8aad176e5a7baf63194d440b2041d8c8fdad6dd541bff3d222db9c"

  url "https://github.com/be5invis/Iosevka/releases/download/v#{version}/PkgTTF-Unhinted-IosevkaSS04-#{version}.zip"
  name "Iosevka SS04"
  homepage "https://typeof.net/Iosevka/"

  font "IosevkaSS04-*.ttf"
end
