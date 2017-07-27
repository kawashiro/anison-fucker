#!/bin/sh
##
#   Script to build anison-fucker application
##

TOR_VERSION=0.3.0.9
APP_VERSION=0.0.1-1

run()
{
    echo "$@" && "$@" || exit 1
}

usage()
{
    echo "Usage:"
    echo "  setup.sh install    Install application system wide"
    echo "  setup.sh deb        Build deb package"
    echo "  setup.sh dev        Prepare development environment"
    echo "  setup.sh clean      Clean build files"
    exit 2
}

clean()
{
    run rm -rf build/*
}

build_tor()
{
    destination="$1"
    if [ -f "$destination" ]; then
        run rm "$destination"
    fi
    run mkdir -p "build/tor"
    src_archive="tor-${TOR_VERSION}.tar.gz"
    if [ ! -f "build/tor/${src_archive}" ]; then
        run wget "https://www.torproject.org/dist/${src_archive}" -O "build/tor/${src_archive}"
        run tar xvzf "build/tor/${src_archive}" -C "build/tor"
    fi
    this_dir="$PWD"
    cd "build/tor/tor-${TOR_VERSION}"
    run ./configure --prefix $(realpath "${PWD}/../dist")
    run make
    run make install-strip
    cd "$this_dir"
    run install -m 755 "build/tor/dist/bin/tor" "$destination"
}

build_app()
{
    destination="$1"
    lib_dir="${destination}/usr/lib/ruby/vendor_ruby"
    bin_dir="${destination}/usr/bin"
    libexec_dir="${destination}/usr/lib/anison-fucker/libexec"

    run mkdir -p "$lib_dir"
    run cp -r "lib/anison-fucker" "$lib_dir/"

    run mkdir -p "$bin_dir"
    run install -m 755 "bin/anison-fucker.rb" "$bin_dir/anison-fucker"

    run mkdir -p "$libexec_dir"
    build_tor "$libexec_dir/tor"
}

build_deb()
{
    run mkdir -p "build/debian/DEBIAN"
    run rm -f dist/*.deb
    arch=$(uname -m)
    if [ "$arch" = "x86_64" ]; then
        arch="amd64"
    fi
    size=$(du -d0 "build/debian/usr" | sed -e 's/\s\+.*$//')
    cat "pkg/debian/control.skel" \
        | sed -e "s/{arch}/${arch}/gi" \
        | sed -e "s/{size}/${size}/gi" \
        > "build/debian/DEBIAN/control"
    build_app "build/debian"
    this_dir="$PWD"
    cd "build/debian"
    md5sum $(find usr/ -type f) > "DEBIAN/md5sums"
    cd "$this_dir"
    run chmod -R g-w "build/debian"
    run fakeroot dpkg-deb --build "build/debian"
    run mkdir -p "dist"
    run mv "build/debian.deb" "dist/ruby-anison-fucker_${APP_VERSION}-${arch}.deb"
}


case "$1" in
    install)
        build_app "$2"
        ;;
    deb)
        build_deb
        ;;
    dev)
        build_tor "bin/tor"
        ;;
    clean)
        clean
        ;;
    *)
        usage
        ;;
esac
