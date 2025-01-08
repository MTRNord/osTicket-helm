#! /bin/sh 

set -e

rm -r /var/www/html/setup 

# Run cron in the background
cron &
# Start apache
exec /usr/sbin/apachectl -D FOREGROUND
