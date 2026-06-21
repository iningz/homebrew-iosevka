#!/usr/bin/env nu

use ./utils.nu *

export def run [tag: string, ver: string] {
    let root = (repo-root)
    let build = (build-dir)
    let src = $build | path join "iosevka-src"
    let casks = (manifest-casks | where {|c| (kind-of $c) == "build" })
    if ($casks | is-empty) {
        error make { msg: "no build casks in fonts.toml" }
    }

    mkdir $build
    if ($src | path exists) {
        ^rm -rf $src
    }
    ^git clone --depth 1 --branch $tag $"https://github.com/(upstream-repo).git" $src

    let plan_text = ($casks | each {|c| private-build-plans-toml (stem-of $c) } | str join "\n")
    $plan_text | save -f ($src | path join "private-build-plans.toml")

    cd $src
    ^npm ci
    for cask in $casks {
        let stem = (stem-of $cask)
        let zip_name = (release-asset-of $cask $ver)
        let zip_path = $build | path join $zip_name

        ^npm run build -- $"ttf-unhinted::($stem)"
        cd ($src | path join $"dist/($stem)/TTF-Unhinted")
        ^zip -r $zip_path ./*.ttf
        print $"wrote ($zip_path)"
        cd $src
    }
}
