#!/usr/bin/env nu
# Regenerate Casks/*.rb from fonts.toml casks list.
# Usage: nu scripts/main.nu bump-casks 34.6.3 [--allow-partial-release]

use ./utils.nu *

export def run [ver: string, --allow-partial-release] {
    let root = (repo-root)
    let manifest = (load-manifest)
    let upstream_sha = (fetch_upstream_sha $ver (upstream-repo))
    let release_assets = (fetch_release_assets $ver (tap-repo))

    mkdir ($root | path join Casks)

    for cask in (manifest-casks) {
        let kind = (kind-of $cask)
        let asset = (release-asset-of $cask $ver)
        let local_asset = (build-dir | path join $asset)
        let source = (if $kind == "upstream" {
            if not ($asset in ($upstream_sha | columns)) {
                error make {msg: $"missing SHA-256 for ($asset) in upstream release"}
            }
            {
                sha: ($upstream_sha | get $asset)
                zip_path: (download_zip $asset (concrete_release_url (upstream-repo) $ver $asset))
            }
        } else if ($asset in ($release_assets | columns)) {
            let release_asset = ($release_assets | get $asset)
            {
                sha: ($release_asset | get sha)
                zip_path: (download_zip $asset ($release_asset | get url))
            }
        } else if ($local_asset | path exists) {
            {
                sha: (open --raw $local_asset | hash sha256)
                zip_path: $local_asset
            }
        } else {
            if $allow_partial_release {
                print -e $"skip ($cask): release asset ($asset) not found"
                continue
            }
            error make {msg: $"missing release asset ($asset) for version ($ver); run release workflow first"}
        })

        let url = (if $kind == "upstream" {
            upstream_url (upstream-repo) (package-of (stem-of $cask))
        } else {
            release_url (tap-repo) $ver $asset
        })
        let font_files = (list_zip_font_files $asset ($source | get zip_path))

        let rb = (render_cask $cask $ver ($source | get sha) $url (manifest-homepage) $font_files)
        $rb | save -f ($root | path join Casks $"($cask).rb")
        print $"wrote ($cask).rb"
    }
}

def fetch_upstream_sha [ver: string, upstream_repo: string] {
    let url = $"https://github.com/($upstream_repo)/releases/download/(tag-of $ver)/SHA-256.txt"
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

def fetch_release_assets [ver: string, repo: string] {
    let api = $"https://api.github.com/repos/($repo)/releases/tags/(tag-of $ver)"
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
        $map = ($map | upsert $name { sha: $hash, url: $dl })
    }
    $map
}

def download_zip [asset: string, url: string] {
    let cache_dir = (build-dir | path join "cask-zips")
    mkdir $cache_dir
    let zip_path = $cache_dir | path join $asset
    http get -r $url | save -f $zip_path
    $zip_path
}

def list_zip_font_files [asset: string, zip_path: path] {
    let listed = (^unzip -Z1 $zip_path | complete)
    if $listed.exit_code != 0 {
        error make { msg: $"failed to list font files in ($asset): ($listed.stderr)" }
    }
    let files = (
        $listed.stdout
        | lines
        | each {|f| $f | str replace -r '^\./' '' }
        | where {|f| $f =~ '\.ttf$' }
        | sort
    )
    if ($files | is-empty) {
        error make { msg: $"asset ($asset) contains no .ttf files" }
    }
    $files
}

def render_cask [cask: string, ver: string, sha: string, url: string, homepage: string, font_files: list<string>] {
    let name = (display-name-of $cask)
    let fonts = ($font_files | each {|font| $"  font \"($font)\"" } | str join "\n")
    $"cask \"($cask)\" do
  version \"($ver)\"
  sha256 \"($sha)\"

  url \"($url)\"
  name \"($name)\"
  homepage \"($homepage)\"

($fonts)
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

def concrete_release_url [repo: string, ver: string, asset: string] {
    $"https://github.com/($repo)/releases/download/(tag-of $ver)/($asset)"
}

def release_url [repo: string, ver: string, asset: string] {
    let v = (version_tag)
    let asset_tpl = ($asset | str replace $"($ver)" $v)
    $"https://github.com/($repo)/releases/download/v($v)/($asset_tpl)"
}
