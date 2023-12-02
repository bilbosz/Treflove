#!/bin/bash

function on_exit() {
    jobs -p | xargs -n1 kill -9
}

trap 'on_exit' EXIT

love . server localhost 8080 &
sleep 0
love . client localhost 8080
