cask "font-iosevka-etoile" do
  version "34.6.3"
  sha256 "fe2b166bff3b49c15dfc820932514bd2e6ebc400fa3d3f64e035465a1095b37f"

  url "https://github.com/be5invis/Iosevka/releases/download/v#{version}/PkgTTF-Unhinted-IosevkaEtoile-#{version}.zip"
  name "Iosevka Etoile"
  homepage "https://typeof.net/Iosevka/"

  font "IosevkaEtoile-*.ttf"
end
