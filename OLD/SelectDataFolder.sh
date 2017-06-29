#! /bin/bash

./SelectDataFolder.pl

x=`cat tmp.tx1`
echo "datafolder = "$x

export PRP2DATAPATH=$x


