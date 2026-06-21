#!/usr/bin/env nu

use ./utils.nu *

export def run [tag: string, ver: string] {
    let build = (build-dir)
    let casks = (manifest-casks | where {|c| (kind-of $c) == "patch" })
    if ($casks | is-empty) {
        error make { msg: "no patch casks in fonts.toml" }
    }
    let patcher_zip = $build | path join "FontPatcher.zip"
    let patcher_dir = $build | path join "fontpatcher"
    let dl_dir = $build | path join "dl"
    let out_dir = $build | path join "out"

    mkdir $build
    mkdir $dl_dir
    mkdir $out_dir

    if not ($patcher_zip | path exists) {
        http get -r $"https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FontPatcher.zip"
            | save -f $patcher_zip
    }
    if ($patcher_dir | path exists) {
        ^rm -rf $patcher_dir
    }
    mkdir $patcher_dir
    ^unzip -q $patcher_zip -d $patcher_dir
    ^chmod +x ($patcher_dir | path join "font-patcher")

    let patcher = $patcher_dir | path join "font-patcher"
    for cask in $casks {
        let term_zip = (upstream-asset-of $cask $ver)
        let term_ttc = (upstream-ttc-of $cask)
        let term_url = $"https://github.com/(upstream-repo)/releases/download/($tag)/($term_zip)"
        let dl_term_zip = $dl_dir | path join $term_zip
        if not ($dl_term_zip | path exists) {
            http get -r $term_url | save -f $dl_term_zip
        }
        ^unzip -q $dl_term_zip -d $dl_dir

        let input_ttc = $dl_dir | path join $term_ttc
        ^fontforge --script $patcher $input_ttc --complete --quiet --no-progressbars --outputdir $out_dir

        let patched = (glob $"($out_dir)/*.ttc")
        if ($patched | is-empty) {
            error make { msg: $"font-patcher produced no .ttc for ($cask)" }
        }
        let dest = $build | path join (release-asset-of $cask $ver)
        ^cp ($patched | first) $dest
        print $"wrote ($dest)"
    }
}
