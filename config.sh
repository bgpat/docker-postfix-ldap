#!/bin/sh

set -e

DOMAIN=${DOMAIN:-domain.tld}
DOMAIN_SUFFIX="dc=`echo $DOMAIN | sed -e 's/\./,dc=/g'`"

cat << EOF > /etc/postfix/master.cf
smtp       inet  n       -       n       -       -       smtpd
pickup     unix  n       -       n       60      1       pickup
cleanup    unix  n       -       n       -       0       cleanup
qmgr       unix  n       -       n       300     1       qmgr
tlsmgr     unix  -       -       n       1000?   1       tlsmgr
rewrite    unix  -       -       n       -       -       trivial-rewrite
bounce     unix  -       -       n       -       0       bounce
defer      unix  -       -       n       -       0       bounce
trace      unix  -       -       n       -       0       bounce
verify     unix  -       -       n       -       1       verify
flush      unix  n       -       n       1000?   0       flush
proxymap   unix  -       -       n       -       -       proxymap
proxywrite unix  -       -       n       -       1       proxymap
smtp       unix  -       -       n       -       -       smtp
relay      unix  -       -       n       -       -       smtp
showq      unix  n       -       n       -       -       showq
error      unix  -       -       n       -       -       error
retry      unix  -       -       n       -       -       error
discard    unix  -       -       n       -       -       discard
local      unix  -       n       n       -       -       local
virtual    unix  -       n       n       -       -       virtual
lmtp       unix  -       -       n       -       -       lmtp
anvil      unix  -       -       n       -       1       anvil
scache     unix  -       -       n       -       1       scache
submission inet  n       -       n       -       -       smtpd
EOF

cat << EOF > /etc/postfix/main.cf
compatibility_level = 2
smtputf8_enable = no
myhostname = ${MYHOSTNAME:-mail.$DOMAIN}
mydomain = ${MYDOMAIN:-$DOMAIN}
mydestination = ${MYDESTINATION:-\$myhostname localhost.\$mydomain localhost \$mydomain}
mynetworks = ${MYNETWORK:-127.0.0.0/8}
virtual_alias_maps = ldap:/etc/postfix/virtual_alias_maps.cf
smtpd_sender_login_maps = ldap:/etc/postfix/smtpd_sender_login_maps.cf
smtpd_client_restrictions =
	permit_mynetworks,
	permit
smtpd_recipient_restrictions =
	permit_sasl_authenticated,
	reject_invalid_hostname,
	reject_non_fqdn_hostname,
	reject_non_fqdn_sender,
	reject_non_fqdn_recipient,
	reject_unknown_sender_domain,
	reject_unknown_recipient_domain,
	reject_unauth_pipelining,
	permit_auth_destination,
	reject_unauth_destination,
	reject
smtpd_sender_restrictions =
	reject_unknown_sender_domain,
	reject_unlisted_sender,
	reject_authenticated_sender_login_mismatch,
	permit
smtpd_sasl_auth_enable = yes
smtpd_sasl_authenticated_header = yes
broken_sasl_auth_clients = yes
EOF

cat << EOF > /etc/postfix/virtual_alias_maps.cf
server_host = ${LDAP_SERVER_HOST}
version = 3
bind = yes
bind_dn = ${LDAP_BIND_DN:-cn=Manager,$DOMAIN_SUFFIX}
bind_pw = ${LDAP_BIND_PW}
search_base = ${ALIAS_SEARCH_BASE:-ou=%U,ou=Group,$DOMAIN_SUFFIX}
query_filter = ${ALIAS_QUERY_FILTER:-(objectClass=mailAccount)}
result_attribute = ${ALIAS_RESULT_ATTRIBUTE:-mail}
dereference = ${ALIAS_DEREFERENCE:-1}
EOF

cat << EOF > /etc/postfix/smtpd_sender_login_maps.cf
server_host = ${LDAP_SERVER_HOST}
version = 3
bind = yes
bind_dn = ${LDAP_BIND_DN:-cn=Manager,$DOMAIN_SUFFIX}
bind_pw = ${LDAP_BIND_PW}
search_base = ${SENDER_SEARCH_BASE:-ou=%U,ou=Group,$DOMAIN_SUFFIX}
query_filter = ${SENDER_QUERY_FILTER:-(objectClass=mailAccount)}
result_attribute = ${SENDER_RESULT_ATTRIBUTE:-uid}
dereference = ${SENDER_DEREFERENCE:-1}
EOF

cat << EOF > /usr/lib/sasl2/smtpd.conf
pwcheck_method: saslauthd
mech_list: PLAIN LOGIN
saslauthd_path: ${SASLAUTHD_PATH}/mux
EOF
