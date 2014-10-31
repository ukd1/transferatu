#!/bin/bash
while true
do
    ps -C ruby,pg_dump,pg_restore,gof3r --no-headers -o comm,rss,vsz,pcpu \
	| awk '{print "sample#" $1 "_rss=" $2 " sample#" $1 "_vsz=" $3 " sample#" $1 "_pcpu=" $4}'
    sleep 60
done
