#!/usr/bin/env nu

const THIS_FILE = (path self)
const SCRIPT_DIR = ($THIS_FILE | path dirname)
const REPO_ROOT = ($SCRIPT_DIR | path dirname)

use ./utils.nu *
use ./version.nu
use ./build.nu
use ./patch.nu
use ./publish.nu
use ./bump-casks.nu

def run-all [] {
    let v = (with-env { REPO_ROOT: $REPO_ROOT } { version state })
    if $v.need_release == "true" {
        print $"would run release: build=($v.need_build) patch=($v.need_patch) ver=($v.ver) tag=($v.tag)"
        print "dry-run; not building or publishing"
        return
    }
    with-env { REPO_ROOT: $REPO_ROOT } {
        bump-casks run $v.ver
    }
    cd $REPO_ROOT
    let diff = (^git diff --stat Casks/ | complete)
    if $diff.exit_code != 0 or ($diff.stdout | str trim) == "" {
        print "Casks already up to date"
    } else {
        print $diff.stdout
    }
}

def main [cmd: string, ...args: string, --allow-partial-release] {
    with-env { REPO_ROOT: $REPO_ROOT } {
        match $cmd {
            "version" => { version run }
            "build" => {
                if ($args | length) != 2 {
                    error make { msg: "usage: build <tag> <ver>" }
                }
                build run $args.0 $args.1
            }
            "patch" => {
                if ($args | length) != 2 {
                    error make { msg: "usage: patch <tag> <ver>" }
                }
                patch run $args.0 $args.1
            }
            "publish" => {
                if ($args | length) != 2 {
                    error make { msg: "usage: publish <ver> <tag>" }
                }
                publish run $args.0 $args.1
            }
            "bump-casks" => {
                if ($args | length) < 1 or ($args.0 | str trim) == "" {
                    error make { msg: "usage: bump-casks <ver> [--allow-partial-release]" }
                }
                if $allow_partial_release {
                    bump-casks run $args.0 --allow-partial-release
                } else {
                    bump-casks run $args.0
                }
            }
            "all" => { run-all }
            _ => { error make { msg: $"unknown subcommand ($cmd)" } }
        }
    }
}
