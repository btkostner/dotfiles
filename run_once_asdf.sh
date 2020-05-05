#!/bin/bash

sudo apt install -yf autoconf build-essential curl git libncurses5-dev libssh-dev m4

asdf plugin update --all

asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf plugin-add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf plugin-add kubectl https://github.com/Banno/asdf-kubectl.git
asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf plugin-add php https://github.com/asdf-community/asdf-php.git
asdf plugin-add rust https://github.com/code-lever/asdf-rust.git
asdf plugin-add terraform https://github.com/Banno/asdf-hashicorp.git

bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring

asdf install elixir 1.10.3-otp-22
asdf install erlang 22.3.2
asdf install kubectl 1.18.2
asdf install nodejs 12.16.2
asdf install terraform 0.12.24

asdf global elixir 1.10.3-otp-22
asdf global erlang 22.3.2
asdf global kubectl 1.18.2
asdf global nodejs 12.16.2
asdf global terraform 0.12.24
