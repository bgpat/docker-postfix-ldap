FROM alpine:3.6

RUN apk add -U --no-cache postfix postfix-ldap rsyslog

COPY entrypoint.sh /entrypoint.sh
COPY config.sh /config.sh

ENTRYPOINT ["/entrypoint.sh"]
HEALTHCHECK CMD postfix status
