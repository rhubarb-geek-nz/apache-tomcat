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

rpm -q apr-devel openssl-devel java-11-openjdk-devel

VERSION=1.2.39
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
	rm -rf tomcat-native-$VERSION-src root $TGTPATH $SPECFILE $BASEDIR
}

trap cleanup 0

cleanup

if test -z "$JAVA_HOME"
then
	for d in $( find /usr/lib*/jvm -name javac)
	do
		if test -x "$d"
		then
			JAVA_HOME=$(dirname $(dirname $d))
			break
		fi
	done

	test -n "$JAVA_HOME"
fi

if test ! -f tomcat-native-$VERSION-src.tar.gz
then
	curl --silent --output tomcat-native-$VERSION-src.tar.gz --fail --location https://dlcdn.apache.org/tomcat/tomcat-connectors/native/$VERSION/source/tomcat-native-$VERSION-src.tar.gz
fi

rm -f *.rpm

tar xfz tomcat-native-$VERSION-src.tar.gz

case "$(uname -m)" in
	amd64 | aarch64 | x86_64 )
		PKGROOT=usr/lib64
		;;
	* )
		PKGROOT=usr/lib
		;;
esac

mkdir -p "$BASEDIR/usr/lib" "$TGTPATH"

(
	set -e

	cd tomcat-native-$VERSION-src/native

	./configure --with-apr=/usr/bin/apr-1-config \
		--with-java-home=$JAVA_HOME \
		--with-ssl=yes \
		"--prefix=/usr"

	make

	make install "DESTDIR=$BASEDIR"
)

rm $BASEDIR/usr/lib/libtc*.a $BASEDIR/usr/lib/libtc*.la

if test ! -d "$BASEDIR/$PKGROOT"
then
	mv "$BASEDIR/usr/lib" "$BASEDIR/$PKGROOT"
fi

(
	cat << EOF
Summary: Apache Tomcat Native Library $VERSION
Name: tomcat-native
Version: $VERSION
Release: $RELEASE
Group: Applications/System
License: GPL
Prefix: /$PKGROOT

%description
The Apache Tomcat Native Library is an optional component for use with Apache Tomcat that allows Tomcat to use certain native resources for performance, compatibility, etc. Specifically, the Apache Tomcat Native Library gives Tomcat access to the Apache Portable Runtime (APR) library's network connection (socket) implementation and random-number generator. See the Apache Tomcat documentation for more information on how to configure Tomcat to use the APR connector.
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

rm "tomcat-native-$VERSION-src.tar.gz"
