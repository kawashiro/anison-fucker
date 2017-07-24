#!/bin/sh
##
#   Script to build anison-fucker application
##

TOR_VERSION=0.3.0.9

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


case "$1" in
    install)
        build_app "$2"
        ;;
    deb)
        # TODO: Implement
        echo "Not implemented :("
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
