export-env {
  add-hook hooks.pre_prompt {
    code: {
      let now = (date now | into int)
      let last_check = ($env.WARP_STATUS_LAST_CHECK? | default 0 | into int)
      if $now < $last_check or ($now - $last_check) >= 30_000_000_000 {
        warp_hook
      }
    }
  }
  warp_hook
}

def --env add-hook [field: cell-path new_hook: any] {
  let field = $field | split cell-path | update optional true | into cell-path
  let old_config = $env.config? | default {}
  let old_hooks = $old_config | get $field | default []
  $env.config = ($old_config | upsert $field ($old_hooks ++ [$new_hook]))
}

def --env warp_hook [] {
    let WARP_CLI = "/Applications/Cloudflare WARP.app/Contents/Resources/warp-cli"
    let SYSTEM_BUNDLE = "/etc/ssl/cert.pem"

    let status = (if ($WARP_CLI | path exists) {
        try { ^$WARP_CLI status | complete } catch { null }
    } else { null })

    let is_connected = (if $status != null and $status.exit_code == 0 {
        $env.WARP_STATUS_LAST_CHECK = (date now | into int)
        $status.stdout | str contains "Connected"
    } else {
        do -i { hide-env WARP_STATUS_LAST_CHECK }
        false
    })

    let warp_certs = if $is_connected {
        glob "/Library/Application Support/Cloudflare/installed_certs/*.pem"
    } else { [] }

    if ($warp_certs | is-empty) {
        $env.WARP_CONNECTED = $is_connected
        do -i { hide-env AWS_CA_BUNDLE }
        do -i { hide-env CURL_CA_BUNDLE }
        do -i { hide-env REQUESTS_CA_BUNDLE }
        do -i { hide-env SSL_CERT_FILE }
        do -i { hide-env NODE_EXTRA_CA_CERTS }
        do -i { hide-env GIT_SSL_CAINFO }
        return
    }

    let cache_dir = $env.XDG_CACHE_HOME | path join "warp"
    let warp_bundle = $cache_dir | path join "warp-ca.pem"
    let full_bundle = $cache_dir | path join "ca-bundle.pem"
    let sources = [$SYSTEM_BUNDLE ...$warp_certs]

    let is_stale = (not ($full_bundle | path exists)) or (
        (ls -D ...$sources | get modified | math max) > (ls -D $full_bundle | get 0.modified)
    )

    if $is_stale {
        mkdir $cache_dir
        $warp_certs | each { open --raw } | str join "\n" | save -f $warp_bundle
        $sources | each { open --raw } | str join "\n" | save -f $full_bundle
    }

    # These variables replace the default trust store, so they need the system
    # roots too. NODE_EXTRA_CA_CERTS is additive.
    $env.WARP_CONNECTED = true
    $env.AWS_CA_BUNDLE = $full_bundle
    $env.CURL_CA_BUNDLE = $full_bundle
    $env.REQUESTS_CA_BUNDLE = $full_bundle
    $env.SSL_CERT_FILE = $full_bundle
    $env.GIT_SSL_CAINFO = $full_bundle
    $env.NODE_EXTRA_CA_CERTS = $warp_bundle
}
