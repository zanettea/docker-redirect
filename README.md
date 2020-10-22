# docker-redirect
Redirects traffic directed to a containerized service to a local service under test so that the local instance can transparently take over the
containerized instance serving client requests.

The script has been tested in Linux, Mac and Windows (WSL2) environments.


```
      +-----------------+      +-----------------+
      |                 |      |                 |
      |  Containerized  |      |    Service X    |
      |    Service X    |      |    under test   |
      |                 |      |                 |
      |   +---------+   |      |   +---------+   |
      |   | Port N  |   |      |   | Port M  |   |
      +---+---------+---+      +---+---------+---+
              |                         ^
            XXXXX        Redirect       |
              +-+-----------------------+
              | |
              | |
         +----------+
         |          |
         |  Client  |
         |          |
         +----------+

```

### Usage:

```
docker_redirect [start|stop] [filter_key] [docker_internal_port =>] [=> local_port]
```

### Example

Consider MyService is an HTTP service of a microservice application running in a container and exposing port 80 to local port 8080:

```
docker run --name MyService -p 8080:80
```

If you want to test a development version of the service in the same test enviroment without redeploying the container you can use `docker-redirect` script.
If the MyService under test is running on local port 8081:

```
docker_redirect start MyService 80 8081
```

In this way all the requests targeting the service will be transparently redirected to the version under test. 

To disable the redirect and restore the normal communication:

```
docker_redirect stop
```

### How it works

IPTables are used to redirect all TCP traffic targeted at the container IP address and port to local ip and port:

```
 $IPTABLES -t nat -A PREROUTING -p tcp -d $IP --dport $DOCKER_PORT  -j DNAT --to $LOCAL_IP:$LOCAL_PORT
 $IPTABLES -t nat -n -L PREROUTING
```

This actually works in Windows (WSL2) and Mac platforms as well because the iptables commands run in a privileged docker container with host networking.

