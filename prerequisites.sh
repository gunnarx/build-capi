#!/bin/sh

# Install dependencies that are not built from source

# Ubuntu flavor:
apt-get install -y build_essential
apt-get install -y flex bison autoconf libtool libexpat-dev
