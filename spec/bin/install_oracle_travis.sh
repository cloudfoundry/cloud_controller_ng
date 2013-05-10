#!/bin/sh

ORACLE_BASE=/opt/oracle
export ORACLE_HOME=$ORACLE_BASE/instantclient_11_2
export LD_LIBRARY_PATH=${ORACLE_HOME}:${LD_LIBRARY_PATH}

echo "*** install oracle ***"
sudo mkdir -p $ORACLE_HOME
cd $ORACLE_BASE
sudo wget $ORACLE_INSTANT_CLIENT_URL
sudo tar -jxf $ORACLE_INSTANT_CLIENT_ZIP
cd $ORACLE_HOME
sudo ln -s libclntsh.so.11.1 libclntsh.so
sudo ln -s libocci.so.11.1 libocci.so
