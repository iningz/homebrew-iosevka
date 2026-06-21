#!/usr/bin/env nu

use ./utils.nu *

def version-state [] {
    let upstream = (http get "https://api.github.com/repos/be5invis/Iosevka/releases/latest")
    let tag = $upstream.tag_name
    if not ($tag =~ '^v[0-9]+\.[0-9]+\.[0-9]+$') {
        error make { msg: $"unexpected upstream tag: ($tag)" }
    }
    let ver = ($tag | str replace "v" "")

    let api = $"https://api.github.com/repos/((tap-repo))/releases/tags/v($ver)"
    let asset_names = (try {
        http get $api | get assets? | default [] | get name
    } catch {
        []
    })

    mut need_build = false
    mut need_patch = false
    for cask in (manifest-casks) {
        let kind = (kind-of $cask)
        if $kind == "upstream" {
            continue
        }
        let asset = (release-asset-of $cask $ver)
        let missing = not ($asset in $asset_names)
        if $missing {
            if $kind == "patch" {
                $need_patch = true
            } else {
                $need_build = true
            }
        }
    }

    let need_release = $need_build or $need_patch
    {
        tag: $tag
        ver: $ver
        need_build: ($need_build | into string)
        need_patch: ($need_patch | into string)
        need_release: ($need_release | into string)
    }
}

export def run [] {
    emit-outputs (version-state)
}

export def state [] {
    version-state
}
