# Paths, manifest, GitHub Actions output, and cask-name derivations.

const THIS_FILE = (path self)

export def repo-root [] {
    $env.REPO_ROOT? | default ($THIS_FILE | path dirname | path dirname)
}

export def build-dir [] {
    repo-root | path join ".build"
}

export def load-manifest [] {
    open (repo-root | path join "fonts.toml")
}

export def manifest-casks [] {
    load-manifest | get casks
}

export def manifest-homepage [] {
    load-manifest | get homepage
}

export def upstream-repo [] {
    load-manifest | get upstream_repo
}

export def tap-repo [] {
    $env.GITHUB_REPOSITORY? | default (load-manifest | get repo)
}

# Canonical version form is bare (e.g. "34.6.3"). Accept either form on input.
export def parse-version [input: string] {
    let s = ($input | str trim | str replace -r '^v' '')
    if not ($s =~ '^[0-9]+\.[0-9]+\.[0-9]+$') {
        error make { msg: $"expected version like v1.2.3 or 1.2.3, got: ($input)" }
    }
    $s
}

# GitHub git tags and release URLs use a leading "v"; asset names do not.
export def tag-of [ver: string] {
    $"v($ver)"
}

export def emit-outputs [pairs: record] {
    for key in ($pairs | columns) {
        let line = $"($key)=($pairs | get $key)"
        if ($env.GITHUB_OUTPUT? | default "") != "" {
            $"($line)\n" | save --append $env.GITHUB_OUTPUT
        }
        print $line
    }
}

# font-iosevka-slab-ss04 -> slab-ss04
export def variant-of [cask: string] {
    $cask | str replace -r '^font-iosevka-' ''
}

def segment-title [seg: string] {
    if ($seg =~ '^ss[0-9]+$') {
        $seg | str upcase
    } else {
        $seg | str capitalize
    }
}

# slab-ss04 -> IosevkaSlabSS04
export def stem-from-variant [variant: string] {
    let parts = ($variant | split row '-' | each {|s| segment-title $s })
    $"Iosevka($parts | str join '')"
}

export def stem-of [cask: string] {
    stem-from-variant (variant-of $cask)
}

# term-ss04-nerd-font -> term-ss04
export def patch-variant-of [cask: string] {
    variant-of $cask | str replace -r '-?nerd-font$' ''
}

export def patch-stem-of [cask: string] {
    stem-from-variant (patch-variant-of $cask)
}

# IosevkaSlabSS04 -> Iosevka Slab SS04
export def family-of [stem: string] {
    $stem | str replace -a -r '([a-z0-9])([A-Z])' '$1 $2'
}

export def kind-of [cask: string] {
    let v = (variant-of $cask)
    if ($v =~ 'nerd') {
        "patch"
    } else if ($v =~ 'slab') {
        "build"
    } else {
        "upstream"
    }
}

export def package-of [stem: string] {
    $"PkgTTF-Unhinted-($stem)"
}

export def inherits-of [stem: string] {
    if not ($stem =~ 'SS[0-9]+') {
        return null
    }
    ($stem | str replace -r '.*(SS[0-9]+).*$' '${1}' | str downcase)
}

export def serifs-of [stem: string] {
    if ($stem =~ 'Slab') {
        "slab"
    } else {
        "sans"
    }
}

export def release-asset-of [cask: string, ver: string] {
    match (kind-of $cask) {
        "patch" => {
            $"((patch-stem-of $cask)).Nerd.Font.ttc"
        }
        _ => {
            $"(package-of (stem-of $cask))-($ver).zip"
        }
    }
}

export def upstream-asset-of [cask: string, ver: string] {
    match (kind-of $cask) {
        "patch" => {
            $"SuperTTC-SGr-((patch-stem-of $cask))-($ver).zip"
        }
        "upstream" => {
            release-asset-of $cask $ver
        }
        "build" => {
            null
        }
    }
}

export def upstream-ttc-of [cask: string] {
    $"SGr-((patch-stem-of $cask)).ttc"
}

export def font-glob-of [cask: string] {
    match (kind-of $cask) {
        "patch" => {
            $"((patch-stem-of $cask)).Nerd.Font.ttc"
        }
        _ => {
            $"(stem-of $cask)-*.ttf"
        }
    }
}

export def display-name-of [cask: string] {
    family-of (stem-of $cask)
}

export def private-build-plans-toml [stem: string] {
    let family = (family-of $stem)
    let serifs = (serifs-of $stem)
    let inherits = (inherits-of $stem)
    mut out = $"
[buildPlans.($stem)]
family = \"($family)\"
serifs = \"($serifs)\"
"
    if $inherits != null {
        $out = $out + $"

[buildPlans.($stem).variants]
inherits = \"($inherits)\"
"
    }
    $out
}
