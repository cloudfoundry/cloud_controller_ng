#!/bin/sh

echo "*** install oracle ***"
sudo mkdir -p $ORACLE_HOME
cd $ORACLE_BASE

sudo wget $CLIENT_BASIC
sudo wget $CLIENT_SDK
sudo wget $CLIENT_SQLPLUS

sudo find . -name "*.zip" -exec tar -zxf {} \;

cd $ORACLE_HOME
sudo ln -s libclntsh.so.11.1 libclntsh.so
sudo ln -s libocci.so.11.1 libocci.so
