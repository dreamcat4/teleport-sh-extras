# teleport-sh-extras

<!-- MarkdownTOC -->

* [Introduction](#introduction)
* [Quick start](#quick-start)
  * [Ubuntu](#ubuntu)
* [tlogsearch_functions.sh](#tlogsearch_functionssh)
  * [Usage](#usage)
  * [Disclaimer](#disclaimer)
* [tdeploy](#tdeploy)
  * [Usage](#usage-1)
  * [Disclaimer](#disclaimer-1)
  * [Some features](#some-features)
  * [Supported Package Formats](#supported-package-formats)
  * [Quick example](#quick-example)
  * [Installing teleport non-interactively](#installing-teleport-non-interactively)
    * [Ubuntu](#ubuntu-1)
* [tsysinfo](#tsysinfo)
  * [Useful for...](#useful-for)
* [Contributing](#contributing)
* [Credit](#credit)

<!-- /MarkdownTOC -->


<a id="introduction"></a>
# Introduction

Some 3rd party helper shell scripts for [gravitational/teleport](https://github.com/gravitational/teleport). These are provided under the same Apache 2.0 license as the main teleport project. All of the scripts within this repository are public domain copyright, there are no licensing or other usage restrictions.

If you wish to upstream any of the features provided here into the main teleport project, by re-writing them into native go, please do so! That would be fantastic. Then these shell scripts can eventually be deprecated / obsoleted in favor of officially teleport functionality.

In the meantime please enjoy these helper scripts for what they are intended to be. Just some rapid prototyping of a few small missing features / funcitonality. That helped me to make teleport work more like the way I needed.

<a id="quick-start"></a>
# Quick start

<a id="ubuntu"></a>
## Ubuntu

These instructions are provided for ubuntu with (`apt install ...`). For other platforms you just need to install the same equivalent packages using your platform's package manager (`yum`, `brew install`, `pacman`, etc).

```sh
# download this repo using git or whatever (http download url if you prefer)
git clone https://github.com/dreamcat4/teleport-sh-extras.git

# tdeploy - install package dependancies
sudo apt install makeself fpm

# tsysinfo - install package dependancies. This should also be done on target teleport nodes
sudo apt install bash sysstat lm-sensors lsscsi smartmontools socat

# tsysinfo - a couple of the subcommands specifically use the `sensors` command from lm-sensors package
# to setup lm-sensors on the target machine you will also need to run the following setup script:
sensors-detect

# tlogsearch_functions.sh - install package dependancies. On the machine with the teleport logs
sudo apt install gzip coreutils colorized-logs xclip
```


<a id="tlogsearch_functionssh"></a>
# tlogsearch_functions.sh

**WARNING: Subject to future breakage. See [Disclaimer](#disclaimer) section.**

This is a small set of shell functions that you can import into your login script `~/.profile` or `~/.bashrc` which make it easier to grep and search through the stored logs of previous teleport sessions on the commandline. Much like you might want to search through your syslog or other unix logs.

To use these function. You must first add something like these lines to your `~/.bashrc` or your `~/.profile`

```sh
# source tlogsearch_functions.sh
. ${HOME}/teleport-sh-extras/tlogsearch_functions.sh

# You need to set these to point to your teleport data folder
_teleport_logs="/var/lib/teleport/data/log"

# set your favorite browser executable, to open logs into after ansi2html
_browser="firefox"
```

<a id="usage"></a>
## Usage

There are several shell functions you can use to grep for teleport logs on the local disk. You can type `tloghelp` for a reminder of what those commands are and how to use them:

```
tloghelp:

  * print this message

tgrep:

  * grep the teleport log files
  * takes grep flags and syntax just omit the <files> at the end
  * tries to remove any troublesome escape or control characters
  * outputs results to stdout, just like grep - because it is grep!
  * also copy each matching session guid to clipboard

tless:

  * tgrep then open in less program each matching log file in turn
  * takes grep flags and syntax just like tgrep
  * tries to remove any troublesome escape or control characters
  * also copy each matching session guid to clipboard

topen:

  * tgrep then open in your \$_browser each matching log file
  * takes a list of session guids to open as its arguments
  * tries to remove any troublesome escape or control characters
  * output is converted to a colorized html file with ansi2html
  * also copy each matching session guid to clipboard

tgopen:
  * combines tgrep with topen, to directly open matches sessions in \$_browser
  * takes grep flags and syntax just like tgrep
  * tries to remove any troublesome escape or control characters
  * output is converted to a colorized html file with ansi2html
  * also copy each matching session guid to clipboard

Examples:

  # grep for something across all the locally found teleport logs, outputs to stdout
  tgrep -i "my search string"

  # open matching sessions in the program less, with ansi colorized output
  tless -i "my search string"

  # get (from the X windows clipboard) the list of session guids where grep found a match
  _teleport_session_guids="\$(xclip -selection clipboard -o)"

  # run those session logs through ansi2html, in a tmp folder, open in \$_browser
  topen \$_teleport_session_guids

  # perform a tgrep, and then directly open the matching session logs in the browser instead of stdout
  tgopen -i "my search string"
```

<a id="disclaimer"></a>
## Disclaimer

These shell functions depend entirely on the underlying layout and storage mechanism of the log files. As they are currently being written to disk in teleport version 4. And without storing them inside of a database!

These functions can search through a teleport logs folder containing `.chunkz.gz` compressed session logs. That are openly searchable on the disk. The way that teleport actually stores all it's session logs is heavily implementation specific. And is entirely subject to change in the future. Not only the log storage format itself may change entirely (for example to json or to another structured text format). But the actual directory structure / session struction may also be subject change too. Or they may no longer be stored and directly accessible on the disk in the future either. As it can also make a lot of sense to store them inside of a database instead. There is no current public or private API for searching through teleport logs. These shell functions may break at any time.

At some point in the future, the teleport project will very likely be changing and improving a set of built-in logging features. For teleport proper, to come in some future version. And we very much look forward to that happening, so that these types of hacks will no longer necessary. Other benefits such as a higher searching performance, pre-indexing, better search capabilities may also then be possible too. Since currently using this mechanism there are going to be performance limitations when searching through a very large number of logs. There are probably quite significant limitations for how fast a program such as `zgrep` can linearly search through a large number of log files on the filesystem. Unless there is a caching or indexing or other mechanism to help speed up subsequent searches.

In the meantime, these shell functions simply provide a very basic log searching mechanism. To search through logs from the commandline and using existing and commonly available unix tools. And perhaps then open the search results in an external editor or other simple program.

The performance on larger log sets has not been tested. But it's expected to be a linear relationship. For example if you have twice as many total logs saved in your cluster. Then performing a search through then may take twice as long.

<a id="tdeploy"></a>
# tdeploy

This script is chiefly for generating installer packages for teleport. But also capable of performing certain other tasks. Tested on ubuntu 19.04, but should also work just fine on other platforms / systems. The assumption of this script is that you have already a working GOLANG environment on this same machine, with a working `$GOPATH` etc. While the extra deployment features also require that this machine has access to the teleport cluster (`tctl` for generating tokens, a working `tsh login` for upgrading target node, etc). Otherwise those features cannot work.

Aso be aware that depending upon the specific package type(s) you wish to build, then there are also some underlying external dependancies. Namely either `makeself.sh` or `fpm` for the tool to actually generate your installer packages. So unless these other tools are also installed, then the only package type that will work is `tarball`.

The main goal of this tool is to generate a reasonable installer package for teleport. However it's also aimed at lower the barrier of entry for initially first installing and trying out teleport. By making it easier for people to generate and distribute binary packaged installers for teleport.

This is also a tool that was designed for making deployment easier in heterogenous environment. Where there are multiple different types of systems / platforms. Wheras in your typical cloud environment there are many very similar nodes to each other. This tool is not meant to replace other existing types of deployment mechanisms for professional or enterprise customers. Configuration management tools such as chef, ansible, saltstack, puppet, etc. So if you are deploying teleport within your enterprise, then please use one of those more appropriate tools instead. However this script may still be useful to you for other parts of the process. For example to create a customized version of an installer package. Which you may then deploy via whichever is your actual preferred deployment mechanism.

<a id="usage-1"></a>
## Usage

Download and install the script as per the [Quick start](#quick-start) installation instructions. The type `tdeploy --help` for the current (most up to date) help. A detailed and very long [help screen](https://github.com/dreamcat4/teleport-sh-extras/blob/9ec4b6d7da11a3ce324da07397c0208a3a630821/tdeploy#L792-L968) including [**these useful examples**](https://github.com/dreamcat4/teleport-sh-extras/blob/9ec4b6d7da11a3ce324da07397c0208a3a630821/tdeploy#L969-L1022). Or see the [Quick example](#quick-example) below.

<a id="disclaimer-1"></a>
## Disclaimer

***Not all package formats are fully working OOB.***

Some will require a little further effort. This same disclaimer is also included [at the top of the script here](https://github.com/dreamcat4/teleport-sh-extras/blob/9ec4b6d7da11a3ce324da07397c0208a3a630821/tdeploy#L12-L29)

The original version has been tested to work well on ubuntu linux based distributions. For the following package types: deb, binary, sh, tarball. And systemd only.
 
Further work and provisions have been made for supporting other package types and also additional service managers other than systemsd. For example: rpm, macos_pkg, snap, launchd, sysv, upstart, runit. Plus a few others. However expect those untested platforms not to work OOB. A little further work is required to get those other formats to work properly and as intended. Until then, they will likely throw an error - PRs welcome.

The [Contributing](#contributing) section further explains how you can help to get the other platforms properly supportted and included.

<a id="some-features"></a>
## Some features

* Per-user (and multiple) configuration settings files, which also include:
* Templates for the teleport.yaml config file to be deployed, the daemon / init system files, etc.
* Ability to include a one-time (or static) provisioning token within the installer package itself
* Choice between 3 different filesystem schemes: Debian, self-contained, or a combination of both.
* Ability to automatically bring up a node as a part of the package installation
* Ability to upgrade teleport on existing nodes within a cluster... using teleport itself as the transport mechanism
* Ability to remove teleport from existing node(s)... useful to clean up previous installations of teleport
* ...and more!

<a id="supported-package-formats"></a>
## Supported Package Formats

The initial support is already included for building the follow package types: `tarball`, `deb`, and generic self extracting installer. And with the init system `systemd`. However there are also quite a few other possible package types. Whatever is supported by the fpm tool. Some of these will require a small amount of extra work to get running (for example RPMs, snap pkg, MacOS pkg, etc). But it's not very difficult - you just need to have a little knowledge of those target platforms, and the ability to test out the resulting packages. To write a little extra code in the missing handler functions. There are already stubs created at those places where they will error out. PRs are welcome.

<a id="quick-example"></a>
## Quick example

Generate a custom installer package (including a unique provisioning token), for debian distributions with a debian files layout, and include a service file for debian's default systemd.

```sh
tdeploy --install --with-token --pkg-type=deb
```

Upgrade all of the nodes in my cluster to the current build in my $GOPATH

```sh
tdeploy --upgrade --nodes=all
```

Try `tdeploy --help` for more detailed guide about the full capabilities of this script.

<a id="installing-teleport-non-interactively"></a>
## Installing teleport non-interactively

<a id="ubuntu-1"></a>
### Ubuntu

Once you have used tdeploy to generate a debian `.deb` apt package. Then you need to install it and bring up teleport on the target node(s). By default the generated teleport package will ask what ip address to bind to / listen on. And then it will immediately proceed with the install and bring up teleport service automatically with systemd.

If you are doing that non-interactively by specifying `DEBIAN_FRONTEND=noninteractive` in your environment. Then teleport will not have the opportunity to ask for the interface to bind to. And instead bind to the default ip address of `0.0.0.0` which is all of the network interfaces.

So the below instructions show how to script a non-interactive installation when you also wih to specify a specific ip address to bind to. Which might change on a per-node basis. For example if you are scripting with another automation tool to manage the installs across multiple machines (ansible, puppet, saltstack, etc).

```sh
# before installing the pkg. must first much disable and mask the teleport.service in systemd
sudo systemctl mask teleport.service

# install telelport
sudo DEBIAN_FRONTEND=noninteractive dpkg -i teleport*.deb

# change the listen_addr setting in the debconf database. This is then also immediately
# written into the `teleport.yaml` configuration file
sudo debconf-set-selections <<EOF
teleport teleport/listen_addr string 127.0.0.1
EOF


# enable and bring up the teleport.service in systemd
sudo systemctl unmask teleport.service
sudo systemctl enable teleport.service

```

A few other useful commands for managing a debian installation...

```sh
# systemd - check status of of teleport service
sudo systemctl status teleport

# systemd - logs of teleport service
sudo journalctl -u teleport.service

# reconfigure teleport listen_addr setting, via interactive ncurses prompt
sudo dpkg-reconfigure teleport

# enable extra debugging information whilst installing teleport debian pkg
# see https://stackoverflow.com/a/36111937/287510 for available debugging levels (-D200 is a good one)
dpkg -i -D200 teleport*.deb

# remove teleport
sudo apt-get purge teleport

# remove / reset the debconf settings database for the teleport apt package
echo PURGE | sudo debconf-communicate teleport

```

<a id="tsysinfo"></a>
# tsysinfo

Print out basic system specs, and system health diagnostic information.

This script which gathers and report back a very short / terse version of specific types of system health. Plus other basic types of system information. So the output is just a minimal number of characters to be displayed on a single line, or put into a variable of another program etc. To give a very quick way to read a system's overall health.

Depending upon which specific subcommand(s) are being invoked, certain few external dependancies may also be required. For example, to report on `systemd` health status, requires that systemd is installed. To report on disk health requires the package `smartmontools`. To report on fan spin requires `lm-sensors` be properly configured. And to report on zfs filesystem health requires that `zfs` and it's kernel module(s) be properly installed.

<a id="useful-for"></a>
## Useful for...

This very basic system reporting is designed to be useful for the following types of applications:

* Dynamic teleport labels
* MOTD - displacy system status information whenever you login / ssh in
* Small hardware lcd diagnostic screens (for home projects such as rpi / similar)
* To be fed into other better reporting tools (zabbix / naigos / similar)
* To be parsed and sent out to push notifications / sms text messages / IM messages / IRC bot / similar.


Quick example:

```sh
$ tsysinfo systemd-health
7 failed services
```

[More examples](https://gist.github.com/dreamcat4/21b67ffe135546697b5411ceb26246f1)

For a full list of all the available subcommands, run `tsysinfo --help`


<a id="contributing"></a>
# Contributing

Pull requests are welcome, or you can open an issue if it's about something you cannot fix yourself and need for me to look at first.

Specifically a small amount of shell code is missing in `tdeploy`, needed to fully finish off support for certain popular packaging formats and init systems. Full support is already provided for debian packages and systemd. Plus generic packages (tarball, self extracting installer). However to fill in for others such as rpm, pacman, MacOS pkgs / launchd, NetBSD...). Well I don't use any of those ones myself, cannot test the resultant packages to ensure that they work. So instead there are some clear stubs left in the code in those few missing spots. And a clear error message is thrown up at those points. For others to fill in.

<a id="credit"></a>
# Credit

Maintainer / contributor history

* Dreamcat4 - dreamcat4@gmail.com




