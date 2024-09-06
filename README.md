# dotfiles

This is a collection of my dotfiles for my setups. This is managed with Chezmoi and git and is built for MacOS but can also (hopefully) be used on Linux.

There are a couple of "patterns" or "groups" my setup usually follows:

1) CLI should be fast as f*ck. When I open a terminal, I want to be able to get to work. No waiting. No loading. Just. Work. :tm:.

- [Mise](https://mise.jdx.dev/) as a package / version manager. It has support for a ton of languages, and has support for `.tool-versions` files which is what our whole org uses. Highly recommended to use this instead of individual managers (like nvm) or installing languages globally.

- [Nushell](https://www.nushell.sh/) for my shell. This is a pretty recent change, but I like it. It has some pretty built in features like color for `ls`. One thing I'll say is it's taking a while to forget previous habits like always writing `ls -hal`.

- [Starship](https://starship.rs/) as my prompt. Again, it's fast and most important, it has sane defaults that I didn't have to spend a ton of time configuring. I have however made some changes to get things to work the way I like.

- [Zoxide](https://github.com/ajeetdsouza/zoxide) as a replacemenf for `cd`. Because it's nice to just do `cd dotfiles` instead of the full `cd Projects/github.com/btkostner/dotfiles`.

2) GUIs should be beautilful and functional, but _not_ take up all of my resources. So I try to use native (not electron) apps as much as I can. This includes:

- [1Password](https://1password.com/) as a password manager. I know it's not native, but it's the best password manager I've used. Syncs to everything. Multiple vaults to keep things organized. And it's got a CLI for when I'm in the terminal or scripting.

- [Alacritty](https://github.com/alacritty/alacritty) for a terminal emulator. It's _extremely_ fast, has a good amount of options, and it's easy to configure.

- [Arc](https://arc.net/) as my browser. It's easy to have multiple profiles for work and personal stuff. Having perminant tabs that don't take a ton of ram is awesome. And using the sidebar for tabs is chefs kiss.

- [Sketch](https://www.sketch.com/) for design work because it's native mac, has awesome export options, popular enough to have plugins and templates, and over all is just a great tool. Worth mentioning that I also use Inkscape because it's open source and dope.

- [Slack](https://slack.com/) for communicating with coworkers. Not my first choice, but not my decision.

- [TablePlus](https://tableplus.com/) for database management. It supports a ton of databases, it's a native mac app, and has some very nice right click menu options for data.

- [Transmit 5](https://panic.com/transmit/) for file transfer. It's an older app, but Panic makes great Mac apps and it connects to anything I need.

- [UTM](https://getutm.app/) for virtual machines. Honestly, I don't use virtual machines that much, but when I do, UTM is the best option I've found.

- [Zed](https://zed.dev/) for code editing. It's a native code editor that's _super_ fast. It doesn't support all of the languages I use yet, but it does most of what I need. For everything that Zed doesn't handle (or is too annoying for), I use VSCode.

3) I have some small utility apps that I use a ton. These include:

- [Tailscale](https://tailscale.com/) for my personal network VPN. It's installed on most of my servers, my nas, phone, etc. It's super simple and just works everywhere.

- [Soulver 3](https://soulver.app/) for quick calculations. If you've never used an app like this, I'd highly recommend having it in your toolbox. It's a much nicer calculator, with unit conversions, and variable support. It's like psudo code for math.

- [Swish](https://highlyopinionated.co/swish/) for window managment. I love tiling window managers, but also with a mix of floating windows. Swish is the best of both worlds and allows me to use this beautiful large macbook touchpad to it's full potential. Plus it supports gaps!

## Applying

So future me, you have a new computer and want to set it up. First off, congrats. Second, run you'll need to install Homebrew, then run this command:

```sh
chezmoi apply --source github.com/btkostner/dotfiles
```
