#!/bin/sh

set -e

touch /var/log/messages /var/log/maillog
/config.sh
newaliases
chown root:root /var/spool/postfix /var/spool/postfix/pid

syslogd
postfix start

tail -f /var/log/*
