#!/usr/bin/env bash


doStuff() {
    [[ -n "$1" ]] && echo "Did Stuff with ${1}." || echo "Gimme Argument to do Stuff."
}

doOther() {
    [[ -n "$1" ]] && echo "Did other Stuff with ${1}." || echo "Gimme Argument to do other Stuff."
}

source ./recursive_dispatch.sh
