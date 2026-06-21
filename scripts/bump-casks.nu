#!/usr/bin/env nu
# Regenerate Casks/*.rb from fonts.toml casks list.
# Usage: nu scripts/main.nu bump-casks 34.6.3 [--allow-partial-release]

use ./utils.nu *

export def run [ver: string, --allow-partial-release] {
    let root = (repo-root)
    let manifest = (load-manifest)
    let upstream_sha = (fetch_upstream_sha $ver (upstream-repo))
    let release_sha = (fetch_release_sha $ver (tap-repo))

    mkdir ($root | path join Casks)

    for cask in (manifest-casks) {
        let kind = (kind-of $cask)
        let asset = (release-asset-of $cask $ver)
        let sha = (if $kind == "upstream" {
            if not ($asset in ($upstream_sha | columns)) {
                error make {msg: $"missing SHA-256 for ($asset) in upstream release"}
            }
            $upstream_sha | get $asset
        } else {
            if not ($asset in ($release_sha | columns)) {
                if $allow_partial_release {
                    print -e $"skip ($cask): release asset ($asset) not found"
                    continue
                }
                error make {msg: $"missing release asset ($asset) for version ($ver); run release workflow first"}
            }
            $release_sha | get $asset
        })

        let url = (if $kind == "upstream" {
            upstream_url (upstream-repo) (package-of (stem-of $cask))
        } else {
            release_url (tap-repo) $ver $asset
        })

        let rb = (render_cask $cask $ver $sha $url (manifest-homepage))
        $rb | save -f ($root | path join Casks $"($cask).rb")
        print $"wrote ($cask).rb"
    }
}

def fetch_upstream_sha [ver: string, upstream_repo: string] {
    let url = $"https://github.com/($upstream_repo)/releases/download/v($ver)/SHA-256.txt"
    let body = (http get -r $url | decode utf-8)
    mut map = {}
    for line in ($body | lines | where {|l| ($l | str trim) != "" }) {
        let parts = ($line | split row "  " | where {|p| ($p | str length) > 0 })
        if ($parts | length) >= 2 {
            $map = ($map | upsert ($parts | last) ($parts | first))
        }
    }
    $map
}

def fetch_release_sha [ver: string, repo: string] {
    let api = $"https://api.github.com/repos/($repo)/releases/tags/v($ver)"
    let release = try {
        http get $api
    } catch {
        return {}
    }
    mut map = {}
    for asset in ($release.assets? | default []) {
        let name = $asset.name
        let dl = $asset.browser_download_url
        let hash = (http get -r $dl | hash sha256)
        $map = ($map | upsert $name $hash)
    }
    $map
}

def render_cask [cask: string, ver: string, sha: string, url: string, homepage: string] {
    let name = (display-name-of $cask)
    let glob = (font-glob-of $cask)
    $"cask \"($cask)\" do
  version \"($ver)\"
  sha256 \"($sha)\"

  url \"($url)\"
  name \"($name)\"
  homepage \"($homepage)\"

  font \"($glob)\"
end
"
}

def version_tag [] {
    ["#", "{version}"] | str join ""
}

def upstream_url [repo: string, package: string] {
    let v = (version_tag)
    $"https://github.com/($repo)/releases/download/v($v)/($package)-($v).zip"
}

def release_url [repo: string, ver: string, asset: string] {
    let v = (version_tag)
    let asset_tpl = ($asset | str replace $"($ver)" $v)
    $"https://github.com/($repo)/releases/download/v($v)/($asset_tpl)"
}
