#!/usr/bin/env bash

set -x

cd ..
rm -rf symfony-template-test/
git clone symfony-template/ symfony-template-test/
cd symfony-template-test/
exec ./start.sh
