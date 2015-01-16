#!/bin/bash

print_stats() {
    while true
    do
	ps -C ruby,pg_dump,pg_restore,gof3r --no-headers -o comm,rss,vsz,pcpu \
	    | awk '{print "'"source=$DYNO"' sample#" $1 "_rss=" $2 "kB sample#" $1 "_vsz=" $3 "kB sample#" $1 "_pcpu=" $4}'
	sleep 60
    done
}

if [[ "$DYNO" == run* && ! -t 1 ]]
then
    print_stats &
fi
