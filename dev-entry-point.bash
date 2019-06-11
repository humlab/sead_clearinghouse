#!/bin/bash

echo "Serving PHP /home/public..."

set -e

if [ ! -e /home/public/api ]; then
    ln -s /home/src/api /home/public/api
fi

if [ ! -e /home/public/vendor ]; then
    ln -s /home/src/vendor /home/public/vendor
fi

if [ ! -e /home/public/upload ]; then
    mkdir /home/public/upload
fi

php -S 0.0.0.0:8060 -t /home/public
