# Fix blackout issue

```shell
$ sudo vi /boot/config.txt 
```



```
[pi02]
hdmi_group=2
hdmi_mode=82
hdmi_safe=1
```





# Enable Web Application

##### Disable authentication

Settings -> Services -> Control

- Require authentication



##### Update port

Settings -> Services -> Control

- change port to `8080`



##### Enable WebSocket

Settings -> Services -> Control

- Allow remote control from applications on other systems



##### Configure reverse proxy for the web application

```shell
$ sudo mkdir -p /etc/nginx/sites-available/media
$ sudo touch /etc/nginx/sites-available/media/locations.conf
$ sudo vim /etc/nginx/sites-available/media/locations.conf
```

Copy and paste:

```nginx
location /media/ {
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_set_header X-NginX-Proxy true;

    proxy_pass http://127.0.0.1:8080/;
    proxy_redirect off;
}

location /media/jsonrpc_http {
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_set_header X-NginX-Proxy true;

    proxy_pass http://127.0.0.1:8080/jsonrpc;
    proxy_redirect off;
}

location /media/jsonrpc {
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
    proxy_set_header Host $host;

    proxy_pass http://127.0.0.1:9090/jsonrpc;
}
```



```shell
$ sudo vim /etc/nginx/sites-enabled/main.conf
```

Append to the end of the `server` block:

```nginx
    # UPS Web UI paths
    include sites-available/media/locations.conf;
```



```shell
$ nginxStop
$ nginxStop
```



##### Update requests paths

```shell
$ sudo vim /usr/share/kodi/addons/webinterface.default/js/kodi-webinterface.js
```

Replace

```javascript
    jsonRpcEndpoint: 'jsonrpc',
    socketsHost: location.hostname,
    socketsPort: 9090,

```

with:

```javascript
    jsonRpcEndpoint: 'sso/media/jsonrpc',
    socketsHost: location.hostname,
    socketsPort: '',
```

> [!TIP]
>
> This removes the port number from the WebSocket requests



Replace

```javascript
  path = (config.getLocal('jsonRpcEndpoint')) + "?" + query;
```

with:

```javascript
  path = (config.getLocal('jsonRpcEndpoint')) + "_http?" + query;
```

> [!TIP]
>
> This separates HTTP requests from WebSocket requests



##### Block external HTTP requests to the UPS server

This forces access to the web application to come through the HTTPS reverse proxy

```shell
$ sudo iptables -A INPUT -p tcp -s localhost --dport 8080 -j ACCEPT
$ sudo iptables -A INPUT -p tcp -s localhost --dport 9090 -j ACCEPT
$ sudo iptables -A INPUT -p tcp --dport 8080 -j DROP
$ sudo iptables -A INPUT -p tcp --dport 9090 -j DROP
```



Verify

```shell
$ sudo iptables -L -v -n --line-numbers
```

```
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination         
1        0     0 ACCEPT     6    --  *      *       127.0.0.1            0.0.0.0/0            tcp dpt:8421
2        0     0 ACCEPT     6    --  *      *       127.0.0.1            0.0.0.0/0            tcp dpt:8422
3       33  1980 DROP       6    --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8421
4        0     0 DROP       6    --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8422
```



Sometimes, the same rule is repeated, to remove a redundant rule

```shell
$ sudo iptables -D INPUT <num>
```









