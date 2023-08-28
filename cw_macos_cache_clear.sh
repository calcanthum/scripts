#!/bin/bash

# Clear System Cache
sudo rm -rf /System/Library/Caches/*

# Clear User Cache
rm -rf ~/Library/Caches/*

# Clear Browser Cache for Safari
rm -rf ~/Library/Safari/Cache.db

# Clear Browser Cache for Google Chrome
rm -rf ~/Library/Caches/Google/Chrome/*

# Clear DNS Cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

echo "Cache cleared."
