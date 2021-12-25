#!/bin/bash

function on_exit() {
    to_kill=$(jobs -p);
    kill -9 $to_kill;
    echo -e "Finished. Killed:\n$to_kill"
}

trap 'on_exit' EXIT

love . server localhost 8080 &
love . client localhost 8080
