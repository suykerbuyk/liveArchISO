#!/bin/bash

set -o nounset
set -o errexit

LAST_MOD=$(curl -sI http://archzfs.com/archzfs/x86_64/archzfs.db | grep -- '^Last-Modified')
LAST_JOB=$(head -1 last-run.txt || true)
LAST_RUN=$(TZ=GMT date "+%a, %d %b %Y %T %Z")

if [ "${LAST_MOD}" != "${LAST_JOB}" ]; then
	cat > last-run.txt <<_
$LAST_MOD
$(TZ=GMT date "+Last-Processed: %a, %d %b %Y %T %Z")
Last-Checked: $LAST_RUN
_

#	rm -f *.xz *.sig *.db *.log *.lck *.files || true

	curl -s http://archzfs.com/archzfs/x86_64/archzfs.db | tar xJf -
	rm -r zfs-archiso-*/

	cat */desc | perl -e'sub urls($$$){
		for("","-headers","-docs") {
			#and then Arch started to use .zst compression
			push(@a,"https://archive.archlinux.org/packages/$2/$1$_/$1$_-$3-x86_64.pkg.tar.zst");
			push(@a, $a[$#a].".sig");
			#but not for all pacakges, so .xz is still a thing
			push(@a,"https://archive.archlinux.org/packages/$2/$1$_/$1$_-$3-x86_64.pkg.tar.xz");
			push(@a, $a[$#a].".sig");
		}
		return join("\n",@a);
	}
	while(<>) {
		if (m/^%DEPENDS/) {
		while(<>) {
			chomp;
			last if $_ eq "";
			m/linux.*=/ && $p{$_}++}
		}
	}
	foreach my $a (keys %p) {
		$a=~s/((.).*)=(.*)/urls($1,$2,$3)/e;
		print "$a\n";
	}' | sort | uniq | wget -i - -nc -o download.log || true

	rm -r zfs-*/ || true

	repo-add --remove --nocolor archzfs-kernels.db.tar.xz *.pkg.tar.zst > repo-add.log
#    rm *.pkg.tar.*

	#echo -- "${LAST_MOD}" >> last-run.txt
else
	sed -re "s/^(Last-Checked: ).*/\1${LAST_RUN}/" -i last-run.txt
fi
