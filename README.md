<div align="center">
  <h1>btkostner/dotfiles</h1>
  <h3>My collection of perfect elementary dotfiles (tm)</h3>
  <br>
  <br>
</div>

---

This is a [chezmoi](https://github.com/twpayne/chezmoi) repository of my perfect
elementray dotfiles (tm). It is synced to all computers I work on, but may not
work for you. Everything in this repository is public (obviously) but it uses
my 1password account to access secrets (will not work for you).

## Init

You will need to [install chezmoi](https://www.chezmoi.io/docs/install/) first.
The easiest way is to just run these commands:

```sh
sudo apt install git
curl -sfL https://git.io/chezmoi | sh
```

Then you will init the repository with:

```sh
~/bin/chezmoi init https://github.com/btkostner/dotfiles.git
```

If you are setting up a new install, you can simply init and apply all in the
same command with:

```sh
~/bin/chezmoi init --apply --verbose https://github.com/btkostner/dotfiles.git
```

Once chezmoi has been applyed for the first time, you can just run `chezmoi`
instead of `~/bin/chezmoi`. Happy hunting!

## Using

To pull down files and apply them to your desktop, run this command:

```sh
chezmoi update --apply --verbose
```

To add files to chezmoi, run this command:

```sh
chezmoi add file.txt
```

To `cd` into the chezmoi repository for git commands, run:

```sh
chezmoi cd
```
