#!/bin/bash

function on_exit() {
    kill -9 $(jobs -p)
}

trap 'on_exit' EXIT

love . server localhost 8080 &
love . client localhost 8080
