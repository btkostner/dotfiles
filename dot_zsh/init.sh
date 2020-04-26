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
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks

fpath=($ZSH/functions $ZSH/completions $fpath)

autoload -U compaudit compinit

for plugin ($ZSH/plugins/*); do
  fpath=($plugin $fpath)
done

compinit -u -C -d "${ZSH_COMPDUMP}"

for config_file ($ZSH/lib/*.zsh); do
  source $config_file
done

for plugin ($ZSH/plugins/*); do
  if [ -f $plugin/$(basename $plugin).plugin.zsh ]; then
    source $plugin/$(basename $plugin).plugin.zsh
  fi
done

for exports ($ZSH/exports/*); do
  source $exports
done

source "$HOME/.asdf/asdf.sh"

source "$ZSH/colors/base16-tomorrow-night.sh"
source "$ZSH/themes/liquidprompt/liquidprompt"
