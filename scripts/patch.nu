#!/usr/bin/env nu

use ./utils.nu *

export def run [version: string] {
    let ver = (parse-version $version)
    let tag = (tag-of $ver)
    let build = (build-dir)
    let casks = (manifest-casks | where {|c| (kind-of $c) == "patch" })
    if ($casks | is-empty) {
        error make { msg: "no patch casks in fonts.toml" }
    }
    let patcher_zip = $build | path join "FontPatcher.zip"
    let patcher_dir = $build | path join "fontpatcher"
    let dl_dir = $build | path join "dl"
    let out_root = $build | path join "out"

    mkdir $build
    mkdir $dl_dir
    mkdir $out_root

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
        let term_url = $"https://github.com/(upstream-repo)/releases/download/($tag)/($term_zip)"
        let dl_term_zip = $dl_dir | path join $term_zip
        if not ($dl_term_zip | path exists) {
            http get -r $term_url | save -f $dl_term_zip
        }
        let input_dir = $dl_dir | path join $cask
        let out_dir = $out_root | path join $cask
        if ($input_dir | path exists) {
            ^rm -rf $input_dir
        }
        if ($out_dir | path exists) {
            ^rm -rf $out_dir
        }
        mkdir $input_dir
        mkdir $out_dir
        ^unzip -q $dl_term_zip -d $input_dir

        let inputs = (glob $"($input_dir)/*.ttf")
        if ($inputs | is-empty) {
            error make { msg: $"upstream asset ($term_zip) contains no .ttf files" }
        }
        for input in $inputs {
            ^fontforge --script $patcher $input --complete --quiet --no-progressbars --outputdir $out_dir
        }

        let patched = (glob $"($out_dir)/*.ttf")
        if ($patched | is-empty) {
            error make { msg: $"font-patcher produced no .ttf files for ($cask)" }
        }
        let dest = $build | path join (release-asset-of $cask $ver)
        ^zip -j $dest ...$patched
        print $"wrote ($dest)"
    }
}
