#!/bin/bash

# Redirects traffic directed to a containerized service to a local service 
# under test so that the local instance can transparently take over the 
# containerized instance serving client requests
#
#      +-----------------+      +-----------------+
#      |                 |      |                 |
#      |  Containerized  |      |    Service X    |
#      |    Service X    |      |    under test   |
#      |                 |      |                 |
#      |   +---------+   |      |   +---------+   |
#      |   | Port N  |   |      |   | Port M  |   |
#      +---+---------+---+      +---+---------+---+
#              |                         ^
#            XXXXX        Redirect       |
#              +-+-----------------------+
#              | |
#              | |
#         +----------+
#         |          |
#         |  Client  |
#         |          |
#         +----------+
#
#
#
# Usage:
# docker_redirect [start|stop] [filter_key] [docker_internal_port =>] [=> local_port]
#
# Eg.
# # docker run --name svcX -p 8080:80 ... 
# # PORT=8081 npm start ...
# docker_redirect start svcX 80 8081
# # ... all requests to localhost:80 are redirected to port 8081   
# docker_redirect stop svcX0
#

KEY=$2

die() {
   echo $1
   exit -1
}

IPTABLES=iptables_wrapper

# run iptables in the docker context (this is for platform portability)
iptables_wrapper() {
   docker run --network=host --privileged --rm -it $( echo -e "\
FROM alpine\n\
RUN apk add -U iptables iproute2\n" | docker  build -q - ) iptables "$@"
}

if [ "$1" == 'start' ]; then
	DOCKER_PORT=$3
	LOCAL_PORT=$4
	# get a local ip (not 127.0.0.1)
	LOCAL_IP=`ifconfig | grep -oe 'inet [0-9\.]\+' | grep -v "127.0.0.1" | awk '{print $2}'`

	IP=`docker inspect -f '{{.Name}} {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -aq) | grep $KEY | awk '{ print $2 }'  | head -n 1`
        [ -n "$IP" ] || die "Cannot determine IP address for a container matching pattern '$2'. Please check if the container is actually running!";
	$IPTABLES -t nat -A PREROUTING -p tcp -d $IP --dport $DOCKER_PORT  -j DNAT --to $LOCAL_IP:$LOCAL_PORT -m comment --comment "docker_redirect ${KEY} traffic"
	$IPTABLES -t nat -n -L PREROUTING
elif [ "$1" == 'stop' ]; then
	IFS=$'\n'

	# remove lines one by one (must iterate since numbering is affected by previous deletion)
	while (( 1 )); do
		rule_ids=`$IPTABLES -t nat -L PREROUTING --line-numbers | grep docker_redirect | grep  "$KEY" | awk '{ print $1 }' `
		if [ -z "$rule_ids" ]; then
			break;
		else
			for rule_id in $rule_ids ; do # take the first
				$IPTABLES -t nat -D PREROUTING $rule_id
				break
			done
		fi;
	done
	$IPTABLES -t nat -n -L PREROUTING
else
	echo "docker_redirect [start|stop] [filter_key] [docker_port =>] [=> local_port]"
	echo
	echo Eg.
	echo "sudo docker_redirect start <match_substring> 8080 80808"
	echo "sudo docker_redirect stop <match_substring>"
	echo

	$IPTABLES -t nat -n -L PREROUTING
	$IPTABLES -t nat -n -L OUTPUT
fi
