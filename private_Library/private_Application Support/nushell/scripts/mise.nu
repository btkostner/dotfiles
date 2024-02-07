export-env {
  $env.MISE_SHELL = "nu"

  $env.config = ($env.config | upsert hooks {
      pre_prompt: ($env.config.hooks.pre_prompt ++
      [{
      condition: {|| "MISE_SHELL" in $env }
      code: {|| mise_hook }
      }])
      env_change: {
          PWD: ($env.config.hooks.env_change.PWD ++
          [{
          condition: {|| "MISE_SHELL" in $env }
          code: {|| mise_hook }
          }])
      }
  })
}

def "parse vars" [] {
  $in | lines | parse "{op},{name},{value}"
}

def --wrapped mise [command?: string, --help, ...rest: string] {
  let commands = ["shell", "deactivate"]

  if ($command == null) {
    ^"/Users/blake.kostner/.local/bin/mise"
  } else if ($command == "activate") {
    $env.MISE_SHELL = "nu"
  } else if ($command in $commands) {
    ^"/Users/blake.kostner/.local/bin/mise" $command ...$rest
    | parse vars
    | update-env
  } else {
    ^"/Users/blake.kostner/.local/bin/mise" $command ...$rest
  }
}

def --env "update-env" [] {
  for $var in $in {
    if $var.op == "set" {
      load-env {($var.name): $var.value}
    } else if $var.op == "hide" {
      hide-env $var.name
    }
  }
}

def --env mise_hook [] {
  ^"/Users/blake.kostner/.local/bin/mise" hook-env -s nu
    | parse vars
    | update-env
}
