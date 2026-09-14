export-env {
  let fnox_hook = {
    code: { fnox_hook }
  }
  add-hook hooks.pre_prompt $fnox_hook
  add-hook hooks.env_change.PWD $fnox_hook
}

def "parse vars" [] {
  $in
  | str trim
  | lines
  | parse 'export {name}="{value}"'
}

def --env add-hook [field: cell-path new_hook: any] {
  let field = $field | split cell-path | update optional true | into cell-path
  let old_config = $env.config? | default {}
  let old_hooks = $old_config | get $field | default []
  $env.config = ($old_config | upsert $field ($old_hooks ++ [$new_hook]))
}

def --env "update-env" [] {
  for $var in $in {
    load-env {($var.name): $var.value}
  }
}

def --env fnox_hook [] {
  # Safely attempt to locate fnox; returns null if missing
  let path = (which fnox | get path? | get 0?)

  if $path == null {
    # fnox not found; do nothing
    return
  }

  try {
    ^$path hook-env -s bash
    | parse vars
    | update-env
  } catch {
    # Ignore errors from fnox
  }
}
