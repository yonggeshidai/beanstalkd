#!/usr/bin/env bash

server=localhost
port=11400
tmpdir="$TMPDIR"
test -z "$tmpdir" && tmpdir=/tmp
out1="${tmpdir}/bnch$$.1"
out2="${tmpdir}/bnch$$.2"
logdir="${tmpdir}/bnch$$.d"
nc='./sh-tests/netcat.py'

killbeanstalkd() {
    {
        test -z "$bpid" || kill -9 $bpid
        /bin/true # Somehow this gets rid of an unnessary shell message.
    } >/dev/null 2>&1
    bpid=
}

cleanup() {
    killbeanstalkd
    rm -rf "$logdir" "$out1" "$out2"
}

catch() {
    echo '' Interrupted
    exit 3
}

trap cleanup EXIT
trap catch HUP INT QUIT TERM

if [ ! -x ./beanstalkd ]; then
  echo "Executable ./beanstalkd not found; do you need to compile first?"
  exit 2
fi

mkdir -p $logdir

./beanstalkd -p $port -b "$logdir" >/dev/null 2>/dev/null &
bpid=$!

sleep .1
if ! ps -p $bpid >/dev/null; then
  echo "Could not start beanstalkd for testing (possibly port $port is taken)"
  exit 2
fi

$nc $server $port <<EOF > "$out1"
put 0 0 100 0

reserve
bury 1 0
quit
EOF

diff - "$out1" <<EOF
INSERTED 1
RESERVED 1 0

BURIED
EOF
