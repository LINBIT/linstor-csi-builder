#!/bin/bash

die() {
	>&2 echo "$1"
	exit 1
}

[ $# -eq 1 ] || die "Usage: $(basename "$0") ARCH"

addentry() {
	local name=$1
	local bm=$2

	printf '[tools-%s]\nname=CentCleafOS-7 - %s\n%s\n' "$name" "$name" "$bm"
	cat <<-'EOF'
	gpgkey=file:///etc/pki/rpm-gpg/tools-key
	gpgcheck=1
	EOF
}

case $1 in
	amd64)
		for i in os extras updates; do
			addentry "$i" "baseurl=http://mirror.centos.org/centos/7/${i}/\$basearch/"
		done
		;;
	s390x)
		# weird enough s390x does not need the extra repo
		addentry 'os' 'mirrorlist=http://mirrors.sinenomine.net/clefos?releasever=7&arch=$basearch&repo=os'
		;;
	*) die "unsupported architecture: $1";;
esac
