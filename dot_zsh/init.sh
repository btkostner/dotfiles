SHORT_HOST=${HOST/.*/}

ZSH_CACHE_DIR="$ZSH/cache"
ZSH_COMPDUMP="$ZDOTDIR/.zcompdump-${SHORT_HOST}-${ZSH_VERSION}"

HISTFILE="$ZDOTDIR/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

HYPHEN_INSENSITIVE="true"
DISABLE_AUTO_UPDATE="true"

setopt inc_append_history
setopt appendhistory
setopt share_history

fpath=($ZSH/functions $ZSH/completions $fpath)

autoload -U compaudit compinit

for plugin ($ZSH/plugins/*); do
  fpath=($plugin $fpath)
done

compinit -u -C -d "${ZSH_COMPDUMP}"

for config_file ($ZSH/lib/*.zsh); do
  source $config_file
done

for plugin ($ZSH/plugins/*/); do
  if [ -f $plugin/$(basename $plugin).plugin.zsh ]; then
    source $plugin/$(basename $plugin).plugin.zsh
  fi
done

source "$ZSH/plugins/liquidprompt/liquid.theme"
