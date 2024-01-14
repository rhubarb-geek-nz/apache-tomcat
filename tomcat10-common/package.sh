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
# $Id: package.sh 313 2024-01-14 17:42:42Z rhubarb-geek-nz $
#

VERSION=10.1.18
INTDIR="$(pwd)"
SPECFILE="$INTDIR/rpm.spec"
TGTPATH="$INTDIR/rpm.dir"
BASEDIR="$INTDIR/root"
PKGROOT=usr/share/tomcat10
RPMBUILD=rpm
RELEASE=$(git log --oneline "$0" | wc -l)

trap "chmod -R +w root ; rm -rf root $SPECFILE $TGTPATH $BASEDIR" 0

if test ! -f "apache-tomcat-$VERSION.tar.gz"
then
	curl --silent --location --fail --output "apache-tomcat-$VERSION.tar.gz" "https://dlcdn.apache.org/tomcat/tomcat-10/v$VERSION/bin/apache-tomcat-$VERSION.tar.gz"
fi

mkdir -p "$TGTPATH" "$BASEDIR/$PKGROOT"

tar xfz  "apache-tomcat-$VERSION.tar.gz"

for d in lib conf bin
do
	mv "apache-tomcat-$VERSION/$d" "$BASEDIR/$PKGROOT/"
done

rm -rf "apache-tomcat-$VERSION" *.rpm "$BASEDIR/$PKGROOT/webapps/"*

if rpmbuild --help >/dev/null
then
    RPMBUILD=rpmbuild
fi

(
	cat << EOF
Summary: Apache Tomcat $VERSION
Name: tomcat10-common
Version: $VERSION
BuildArch: noarch
Release: $RELEASE
Requires: tomcat-native
Group: Applications/System
License: GPL
Prefix: /$PKGROOT

%description
The Apache Tomcat(R) software is an open source implementation of the Jakarta Servlet, Jakarta Server Pages, Jakarta Expression Language, Jakarta WebSocket, Jakarta Annotations and Jakarta Authentication specifications. These specifications are part of the Jakarta EE platform.

EOF

	echo "%files"
	echo "%defattr(-,root,root)"
	cd "$BASEDIR"

	find "$PKGROOT" | while read N
	do
		if test -L "$N"
		then
			echo "/$N"
		else
			if test -d "$N"
			then
				echo "%dir %attr(555,root,root) /$N"
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
		fi
	done

	echo
	echo "%clean"
	echo echo clean "$\@"
	echo
) >$SPECFILE

"$RPMBUILD" --buildroot "$BASEDIR" --define "_build_id_links none" --define "_rpmdir $TGTPATH" -bb "$SPECFILE"

find  "$TGTPATH" -type f -name "*.rpm" | while read N
do
	mv "$N" .
done

rm "apache-tomcat-$VERSION.tar.gz"
