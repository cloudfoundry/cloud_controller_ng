#!/bin/sh
set -e

echo "*** install oracle ***"
sudo mkdir -p $ORACLE_HOME
cd $ORACLE_BASE

sudo apt-get update -qq
sudo apt-get install -qq libaio1

sudo wget -q $CLIENT_BASIC
sudo wget -q $CLIENT_SDK
sudo wget -q $CLIENT_SQLPLUS

sudo find . -name "*.zip" -exec unzip {} \;

cd $ORACLE_HOME
sudo ln -s libclntsh.so.11.1 libclntsh.so
sudo ln -s libocci.so.11.1 libocci.so
