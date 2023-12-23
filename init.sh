#!/bin/bash
if [[ $1 == "" ]]
then
    echo "Usage: ./init.sh <user.email> <user.name>";
    exit
fi
git config --global user.email $1
git config --global user.name $2
git submodule update --init --recursive
