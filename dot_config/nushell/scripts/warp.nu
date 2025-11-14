export-env {
  let warp_hook = {
    code: { warp_hook }
  }
  add-hook hooks.pre_prompt $warp_hook
  add-hook hooks.env_change.PWD $warp_hook
}

def --env add-hook [field: cell-path new_hook: any] {
  let field = $field | split cell-path | update optional true | into cell-path
  let old_config = $env.config? | default {}
  let old_hooks = $old_config | get $field | default []
  $env.config = ($old_config | upsert $field ($old_hooks ++ [$new_hook]))
}

def --env warp_hook [] {
    let CLOUDFLARE_CERT = "/Library/Application Support/Cloudflare/installed_cert.pem"
    let WARP_CLI = "/Applications/Cloudflare WARP.app/Contents/Resources/warp-cli"

    let is_connected = (if ($WARP_CLI | path exists) {
        try { ^$WARP_CLI status | str contains "Connected" } catch { false }
    } else { false })

    if $is_connected {
        $env.WARP_CONNECTED = true
        $env.AWS_CA_BUNDLE = $CLOUDFLARE_CERT
        $env.CURL_CA_BUNDLE = $CLOUDFLARE_CERT
        $env.REQUESTS_CA_BUNDLE = $CLOUDFLARE_CERT
        $env.SSL_CERT_FILE = $CLOUDFLARE_CERT
        $env.NODE_EXTRA_CA_CERTS = $CLOUDFLARE_CERT
        $env.GIT_SSL_CAINFO = $CLOUDFLARE_CERT
    } else {
        $env.WARP_CONNECTED = false
        do -i { hide-env AWS_CA_BUNDLE }
        do -i { hide-env CURL_CA_BUNDLE }
        do -i { hide-env REQUESTS_CA_BUNDLE }
        do -i { hide-env SSL_CERT_FILE }
        do -i { hide-env NODE_EXTRA_CA_CERTS }
        do -i { hide-env GIT_SSL_CAINFO }
    }
}
