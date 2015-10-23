#!/bin/sh

function hex() {
	xxd -p -c 256
}

echo "AaAa" | hex