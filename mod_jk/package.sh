#!/bin/sh -e
#
#  Copyright 2022, Roger Brown
#
#  This file is part of rhubarb-geek-nz/apache-tomcat.
#
#  This program is free software: you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation, either version 3 of the License, or (at your
#  option) any later version.
# 
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
#  more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#
#

rpm -q ant httpd-devel

VERSION=1.2.49
SPECFILE=$(pwd)/rpm.spec
TGTPATH=$(pwd)/rpm.dir
BASEDIR=$(pwd)/root
RPMBUILD=rpm
RELEASE=$(git log --oneline "$0" | wc -l)

if rpmbuild --help >/dev/null
then
    RPMBUILD=rpmbuild
fi

cleanup()
{
	rm -rf tomcat-connectors-$VERSION-src $TGTPATH $SPECFILE $BASEDIR
}

trap cleanup 0

cleanup

rm -f mod_jk*.rpm

case "$(uname -m)" in
	amd64 | aarch64 | x86_64 )
		PKGROOT=usr/lib64/httpd/modules
		;;
	* )
		PKGROOT=usr/lib/httpd/modules
		;;
esac

ls /$PKGROOT/mod_*.so > /dev/null

if test ! -f tomcat-connectors-$VERSION-src.tar.gz
then
	curl --silent --output tomcat-connectors-$VERSION-src.tar.gz --fail --location https://dlcdn.apache.org/tomcat/tomcat-connectors/jk/tomcat-connectors-$VERSION-src.tar.gz
fi

tar xfz tomcat-connectors-$VERSION-src.tar.gz

mkdir -p "$BASEDIR/$PKGROOT" "$TGTPATH"

(
	set -e

	cd tomcat-connectors-$VERSION-src/native

	./configure --with-apxs=/usr/bin/apxs

	make

	find . -name mod_jk.so -type f | grep -v "\.lib*" | while read N
	do
		strip "$N"
		mv "$N" "$BASEDIR/$PKGROOT/" 
	done
)

ls -ld "$BASEDIR/$PKGROOT/mod_jk.so"

(
	cat << EOF
Summary: Tomcat Connectors $VERSION
Name: mod_jk
Version: $VERSION
Release: $RELEASE
Group: Applications/System
Requires: httpd
License: GPL
Prefix: /$PKGROOT

%description
The Apache Tomcat Connectors project is part of the Tomcat project and provides web server plugins to connect web servers with Tomcat and other backends.

EOF

	echo "%files"
	echo "%defattr(-,root,root)"
	cd "$BASEDIR"

	find $PKGROOT | while read N
	do
		if test -L "$N"
		then
			echo "/$N"
		else
			if test -f "$N"
			then
				if test -x "$N"
				then
					echo "%attr(555,root,root) /$N"
				else
					echo "%attr(444,root,root) /$N"	
				fi
			fi
		fi
	done

	echo
	echo "%clean"
	echo echo clean "$\@"
	echo
) > "$SPECFILE"

"$RPMBUILD" --buildroot "$BASEDIR" --define "_build_id_links none" --define "_rpmdir $TGTPATH" -bb "$SPECFILE"

find  "$TGTPATH" -type f -name "*.rpm" | while read N
do
	basename "$N"
	rpm -qlvp "$N"
	mv "$N" .
done

rm tomcat-connectors-$VERSION-src.tar.gz
