#!/bin/sh

PKGNAME=$1

# Sannity check
if [[ -z "$PKGNAME" ]]
then
echo "You must specify a package name"
exit 1
fi

# Dont install a package if it already exists
if pacman -Q -- $PKGNAME > /dev/null 2> /dev/null
then
echo "$PKGNAME already installed."
exit 0
fi

# Check if the aur package exists
curl -- "https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=$PKGNAME" > ~/.tinyaur/fetch
CURLRESULT="$?"
grep '"resultcount":0,' ~/.tinyaur/fetch > /dev/null
GREPRESULT="$?"
if [[ "$CURLRESULT" == 0 && "$GREPRESULT" == "0" ]]
then
	# If the aur does not have a pakage, install with pacman
	echo "Installing $PKGNAME from offical repos"
	sudo pacman -S $PACMANFLAGS $PACMANFLAGSINTERNAL -- $PKGNAME || exit 1
	exit 0
elif [[ "$CURLRESULT" == 0 && "$GREPRESULT" == "1" ]]
then
	# if the aur package exists, try to install it
	echo "Installing $PKGNAME from aur..."

	mkdir ~/.tinyaur/ 2>/dev/null || true
	cd ~/.tinyaur
	echo "Cloning git repo"
	git clone -- "https://aur.archlinux.org/$PKGNAME.git"
	cd $PKGNAME
	vim PKGBUILD
	grep "^depends=" PKGBUILD | cut -d "(" -f 2 | cut -d ')' -f 1 | sed "s/[\"\']//g" > deps
	grep "^makedepends=" PKGBUILD |  cut -d "(" -f 2 | cut -d ')' -f 1 | sed "s/[\"\']//g" >> deps
	grep "^checkdepends=" PKGBUILD |  cut -d "(" -f 2 | cut -d ')' -f 1 | sed "s/[\"\']//g" >> deps
	cat deps | sed "s/ /\n/g" | PACMANFLAGSINTERNAL="--asdeps" xargs -o -i{} "$0"  {}
	makepkg || exit 1
	sudo pacman -U $PACMANFLAGS $PACMANFLAGSINTERNAL -- $PKGNAME*.pkg.tar.zst || exit 1
	echo "Installed"
	exit 0
else
	# If all that fails, exit
	echo "Faild quering package, do you have a working internet connection?"
	exit 1
fi
