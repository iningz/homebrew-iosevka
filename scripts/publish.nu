#!/usr/bin/env nu

use ./utils.nu *

export def run [ver: string, tag: string] {
    let build = (build-dir)
    let vtag = $"v($ver)"
    mut upload = []

    for cask in (manifest-casks) {
        if (kind-of $cask) == "upstream" {
            continue
        }
        let asset = (release-asset-of $cask $ver)
        let path = $build | path join $asset
        if ($path | path exists) {
            $upload = ($upload | append $path)
        }
    }

    if ($upload | is-empty) {
        error make { msg: "no release assets to upload under .build/" }
    }

    let release_link = $"https://github.com/(upstream-repo)/releases/tag/($tag)"
    let notes = $"[Iosevka ($tag)]" + '(' + $release_link + ')'
    let view = (^gh release view $vtag | complete)
    if $view.exit_code == 0 {
        ^gh release upload $vtag ...$upload --clobber
    } else {
        ^gh release create $vtag ...$upload --title $"Iosevka ($ver)" --notes $notes
    }
    print $"published ($upload | length) asset(s) to release ($vtag)"
}
