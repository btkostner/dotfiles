def native-prompt-git [directory: string] {
    try {
        mut current = $directory
        loop {
            let marker = ($current | path join '.git')
            let kind = (try { $marker | path type } catch { '' })
            if $kind in ['dir' 'file'] {
                let git_dir = if $kind == 'dir' {
                    $marker
                } else {
                    let pointer = (open --raw $marker | str trim)
                    if not ($pointer | str starts-with 'gitdir: ') { return '' }
                    let target = ($pointer | str substring 8.. | str trim)
                    if ($target | str starts-with '/') {
                        $target
                    } else {
                        $current | path join $target
                    }
                }
                let head = (open --raw ($git_dir | path join 'HEAD') | str trim)
                if ($head | str starts-with 'ref: refs/heads/') {
                    return ($head | str substring 16..)
                }
                if ($head =~ '^[0-9a-fA-F]{40,64}$') {
                    return ($head | str substring 0..7)
                }
                return ''
            }
            let parent = ($current | path dirname)
            if $parent == $current { return '' }
            $current = $parent
        }
    } catch { '' }
}

def native-prompt [] {
    let pwd = ($env | get --optional PWD | default '')
    let home = $env.HOME
    let directory = if $pwd == $home {
        '~'
    } else if ($pwd | str starts-with $"($home)/") {
        $"~($pwd | str substring ($home | str length)..)"
    } else {
        $pwd
    }

    mut context = ''
    let branch = (native-prompt-git $pwd)
    if $branch != '' {
        let branch = if ($branch | str length) > 32 {
            $"($branch | str substring 0..28)…"
        } else { $branch }
        $context = $"($context) on (ansi magenta_bold)git ($branch)(ansi reset)"
    }
    let node_project = (['package.json' 'node_modules' '.node-version' '.nvmrc'] | any {|name|
        try { $pwd | path join $name | path exists } catch { false }
    })
    if $node_project {
        $context = $"($context) via (ansi green_bold)nodejs(ansi reset)"
    }
    let duration = (try {
        $env | get --optional CMD_DURATION_MS | default 0 | into int
    } catch { 0 })
    if $duration >= 2000 {
        let seconds = ($duration / 1000 | math round --precision 1)
        $context = $"($context) took (ansi yellow_bold)($seconds)s(ansi reset)"
    }

    let columns = (try { (term size).columns } catch { 80 })
    let width = ([12 ($columns - ($context | ansi strip | str length) - 1)] | math max)
    let directory = if ($directory | str length) > $width {
        $"…($directory | str substring (($directory | str length) - $width + 1)..)"
    } else { $directory }
    $"(char newline)(ansi cyan_bold)($directory)(ansi reset)($context)(char newline)"
}

def native-prompt-indicator [normal: bool] {
    let status = ($env | get --optional LAST_EXIT_CODE | default 0)
    let color = if $status == 0 { ansi green_bold } else { ansi red_bold }
    let symbol = if $normal { '<' } else if $status == 0 { '>' } else { 'x' }
    $"($color)($symbol)(ansi reset) "
}

$env.PROMPT_COMMAND = {|| native-prompt }
$env.PROMPT_COMMAND_RIGHT = ''
$env.PROMPT_INDICATOR = {|| native-prompt-indicator false }
$env.PROMPT_INDICATOR_VI_INSERT = {|| native-prompt-indicator false }
$env.PROMPT_INDICATOR_VI_NORMAL = {|| native-prompt-indicator true }
$env.PROMPT_MULTILINE_INDICATOR = $"(ansi cyan):: (ansi reset)"
