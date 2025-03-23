# Prerequisite

This documentation is made for the **Raspberry Pi 4B** and it is to be equipped with

- an aluminium **heat sink** the same size as the Raspberry Pi
  - passive cooling
- a fast **SD card** with an ample amount of storage
  - 512GB with 90MB/s write in this case
- a USB Coral **TPU**
  - need a USB hub with inline power
- a **UPS**
  - a PiSugar 3 Plus in this case
  - need a power supply with 5V 2.5A rating



Furthermore, this documentation assumes the Raspberry Pi 4B sits behind a router that

- has no wireless connection
- can be accessed physically, only
- is placed in a secure location
- is connected to a Hikvision camera
- disables all inbound communication except port 443





# Setup SD Card

Install and run `rpi-imager` on a computer

- in Fedora, install `rpi-imager` from Discover



##### Flash image to SD card

- pick the 64 bit lite version of the Raspberry Pi OS
- do not setup hostname
- enable SSH
- set user name as `pi`
- set user password
- do not setup WiFi
- configure timezone





# Assemble Raspberry Pi

The TPU will be plugged into the USB hub in a later step, leave the TPU aside for now. Also make sure the lithium batter is detached from the Pi Sugar 3 Plus board before commencing.

- insert the SD card
- install the heat-sink and the UPS
- plug the Raspberry Pi into a local Ethernet network with internet access
- attach the lithium battery to the UPS
- plug the power supply into the UPS



At this point, the Raspberry Pi should start to boot.





# Configure Raspberry Pi

Head over to the router admin page to figure out the Raspberry Pi's IP address and reserve this IP address for the Raspberry Pi.



##### Sign into the Raspberry Pi with public key

Assuming the computer we're signing in from has a RSA encryption key pair already, we can send a copy of the public key to the Raspberry Pi.

```shell
$ ssh-copy-id pi@<ip-address>
```

Note, this also performs a sign-in, and subsequent sign-ins (*i.e.* `ssh pi@<ip-address>`) will not require password



From this point on, all commands are executed on the Raspberry Pi.



##### Install text editor

Vim has syntax highlighting

```shell
$ sudo apt-get install vim
```



##### Update boot loader and firmware

```shell
$ sudo apt-get install rpi-eeprom
$ sudo rpi-eeprom-update
```

Note, follow the on screen instructions



##### Assign more memory to GPU

The default amount of memory assigned to the GPU is 76 MB which may not be sufficient for video hardware acceleration (ref: [link 1](https://dowcs.frigate.video/frigate/installation/#raspberry-pi-34))

- the recommended minimum amount is 128 MB (ref: [link](https://docs.frigate.video/configuration/hardware_acceleration#raspberry-pi-34))
- the recommended maximum amount is 512 MB

```shell
$ sudo vim /boot/firmware/config.txt
```

Append:

```shell
# Set GPU memory amount
gpu_mem=256
```



Verify

```shell
$ sudo reboot

$ vcgencmd get_mem gpu
```





##### Disable WiFi and Bluetooth

```shell
$ sudo vim /boot/firmware/config.txt
```

Append:

```shell
# Disable wifi and bluetooth
dtoverlay=disable-wifi
dtoverlay=disable-bt
```



```shell
$ sudo systemctl disable wpa_supplicant

$ sudo systemctl disable hciuart
$ sudo systemctl disable bluetooth
```



Verify

```shell
$ sudo reboot

$ ifconfig
$ sudo btmgmt info
```





# Customize shell

```shell
$ sudo apt-get install bc

$ touch ~/.bash_profile
$ vim ~/.bash_profile
```

Append:

```shell
# === fix terminal colour

source /etc/skel/.bashrc

# === some colours

setColorYellow="\e[33m"
setColorRed="\e[31m"
setColorGreen="\e[32m"
resetColor="\0033[0m"

# === execute upon login

function dfHighlight {
  df -h | while read line ; do
    if [ "$(echo $line | grep '/$')" ]; then
      diskFullPercent=$(echo "$line" | sed 's|\(.*\)%.*|\1|; s|.* \(.*\)|\1|' | bc)
      [[ $diskFullPercent -gt 89 ]] && echo -e "$setColorRed$line$resetColor" || { [[ $diskFullPercent -gt 79 ]] && echo -e "$setColorYellow$line$resetColor" || echo -e "$setColorGreen$line$resetColor"; }
    else
      echo -e "$line"
    fi
  done
}

# display the SD card usage upon sign-in
dfHighlight;
```





# Install HTTPS Server

An HTTPS server is to be established for hosting reverse proxies for various web applications, one of which is an SSO web application. Hence, HTTPS encryption is necessary.



##### Install Nginx

```shell
$ sudo apt-get install iptables nginx apache2-utils
$ sudo mkdir -p /etc/nginx/logs
$ vim ~/.bash_profile
```

Append:

```shell
# === nginx
alias nginxStart="sudo /etc/init.d/nginx start"
alias nginxStop="sudo /etc/init.d/nginx stop"
alias nginxLog="cd /etc/nginx/logs"
alias nginxRoot="cd /var/www"
```





##### Generate self-signed certificate for the HTTPS server

```shell
$ sudo mkdir -p /etc/nginx/ssl/reverse-proxy
$ cd /etc/nginx/ssl/reverse-proxy
$ sudo openssl req -x509 -nodes -days 14608 -newkey rsa:2048 -keyout nginx.key -out nginx.crt
```



##### Route external HTTP requests to a HTTPS server

```shell
$ cd /etc/nginx/sites-enabled
$ sudo rm default
$ sudo touch /etc/nginx/sites-available/main.conf
$ sudo ln -s /etc/nginx/sites-available/main.conf ./
$ sudo vim main.conf
```

Copy and paste:

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server ipv6only=on;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;

    access_log  /etc/nginx/logs/reverse-proxy.log;

    index index.html index.htm;

    ssl_certificate ssl/reverse-proxy/nginx.crt;
    ssl_certificate_key ssl/reverse-proxy/nginx.key;
}
```



##### Start the servers

```shell
$ nginxStop
$ nginxStart
```



Visit `http://<ip-address>` to verify the browser is 301 redirected to `https://<ip-address>`, also verify Nginx runs on start up

```shell
$ sudo systemctl is-enabled nginx
```





# Install homepage and SSO

##### Create a credential

Hash a password

```shell
$ read -p "Enter the password: " password && echo -n "$password" | openssl dgst -sha256 -hex
```

Copy the password hash



Create and store an SSO account

```shell
$ sudo htpasswd -cB /etc/nginx/.htpasswd <username>
```

Paste the password hash



##### Configure the homepage

```shell
$ sudo mkdir /etc/nginx/sites-available/home-app
$ sudo touch /etc/nginx/sites-available/home-app/locations.conf
$ sudo vim home-app/locations.conf
```

Copy and paste:

```nginx
auth_basic "Authentication Required";
auth_basic_user_file .htpasswd;
root /home/pi/home-app;
error_page 401 =200 /sign-in.html;

location / {
        auth_basic off;
        root /home/pi/home-app;
}

location @forbidden403 {
        auth_basic off;
        return 403;
}

location @dummy-empty-json-object {
        auth_basic off;
        return 200 "{}";
}

location = /auth {
        error_page 401 = @forbidden403;
        try_files DUMMY @dummy-empty-json-object;
}

location ~ ^/sso/(?P<request_basename>.*)$ {
        auth_basic off;
        proxy_pass "$scheme://127.0.0.1/$request_basename";
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_pass_request_headers on;
        proxy_set_header Authorization $cookie_authorization;
}
```



```shell
$ sudo vim /etc/nginx/sites-enabled/main.conf
```

Append to the end of the `server` block:

```nginx
    # Homepage and Authentication
    include sites-available/home-app/locations.conf;
```



##### Create a homepage

```shell
$ mkdir ~/home-app
$ touch ~/home-app/index.html
$ vim ~/home-app/index.html
```

Copy and paste:

```html
<html>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <head>
    <title>Home</title>
    <link rel="icon" type="image/x-icon" href="favicon.png" />
  </head>
  <style>
    html,
    body {
      height: 100%;
      font-size: 62.5%;
      box-sizing: border-box;
    }
    body {
      display: flex;
      justify-content: center;
      align-items: center;
      font-family: "Helvetica Neue", sans-serif;
      background-color: #f7f7f7;
    }
    .app-link-container {
      display: flex;
      flex-direction: column;
      width: 100%;
      max-width: 30rem;
      max-height: 50vh;
      overflow-y: scroll;
      padding: 2rem;
      border-radius: 4px;
      background-color: #ffffff;
      box-shadow: 0 11px 15px -7px rgb(0 0 0 / 20%),
        0 24px 38px 3px rgb(0 0 0 / 14%), 0 9px 46px 8px rgb(0 0 0 / 12%);
    }
    .app-link {
      display: flex;
      align-items: center;
      position: relative;
      font-size: 1.8rem;
      font-weight: 600;
      text-decoration: none;
      padding: 1.6rem;
    }
    .app-link + .app-link {
      margin-top: 2.4rem;
    }
    .app-link,
    .app-link:visited {
      color: inherit;
    }
    .app-link:before {
      flex-shrink: 0;
      content: " ";
      width: 5.2rem;
      height: 5.2rem;
      margin-right: 2.4rem;
      background-size: contain;
      background-repeat: no-repeat;
      background-position: center;
    }
    .app-link:after {
      flex-shrink: 0;
      position: absolute;
      left: 0;
      content: " ";
      width: 8rem;
      height: 8rem;
      border: 1px solid #e1e1e1;
      border-radius: 50%;
    }
    .app-icon__pi-sugar:before {
      background-image: url("app-icon__pi-sugar.png");
    }
    .app-icon__frigate:before {
      background-image: url("app-icon__frigate.png");
    }
    .app-link__label-container {
      display: flex;
      flex-wrap: wrap;
      min-width: 0;
    }
    .app-link__label {
      flex-basis: 100%;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .app-link__label + .app-link__label {
      color: #b2b2b2;
    }
  </style>
  <body>
    <div class="app-link-container">
      <a class="app-link app-icon__pi-sugar" href="/sso/ups/">
        <div class="app-link__label-container">
          <span class="app-link__label"> UPS </span>
          <span class="app-link__label"> PiSugar </span>
        </div>
      </a>
      <a class="app-link app-icon__frigate" href="/sso/nvr/">
        <div class="app-link__label-container">
          <span class="app-link__label"> NVR </span>
          <span class="app-link__label"> Frigate </span>
        </div>
      </a>
    </div>
  </body>
</html>
```



##### Create a sign-in page

```shell
$ touch ~/home-app/sign-in.html
$ vim ~/home-app/sign-in.html
```

Copy and paste:

```html
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Sign in</title>
    <style>
      html,
      body {
        height: 100%;
        font-size: 62.5%;
        box-sizing: border-box;
      }
      body {
        display: flex;
        justify-content: center;
        align-items: center;
      }
      .sign-in-container {
        display: flex;
        flex-direction: column;
        width: 100%;
        max-width: 30rem;
        padding: 2rem;
        border-radius: 4px;
        background-color: #ffffff;
        box-shadow: 0 11px 15px -7px rgb(0 0 0 / 20%),
          0 24px 38px 3px rgb(0 0 0 / 14%), 0 9px 46px 8px rgb(0 0 0 / 12%);
      }
      .input-label:after {
        content: ":";
      }
      .input-label,
      .input-value {
        font-size: 1.4rem;
        font-family: "Helvetica Neue", sans-serif;
      }
      .input-label {
        font-weight: bold;
      }
      .input-label + .input-value {
        margin-top: 0.8rem;
      }
      .input-value + .input-label {
        margin-top: 1rem;
      }
      .input-value + .sign-in-cta {
        margin-top: 3rem;
      }
      .sign-in-cta {
        align-self: center;
      }
    </style>
  </head>
  <body>
    <form class="sign-in-container">
      <label for="username" class="input-label">Username</label>
      <input
        id="username"
        name="username"
        class="input-value"
        type="text"
        required
        autocomplete="username"
      />
      <label for="password" class="input-label">Password</label>
      <input
        id="password"
        name="password"
        class="input-value"
        type="password"
        required
        autocomplete="current-password"
      />
      <button class="sign-in-cta" type="submit">Sign in</button>
    </form>
    <script type="text/javascript">
      let signInAppScope = {};
      signInAppScope.apiPath = "/";
      signInAppScope.authPath = "auth";

      signInAppScope.sha256Hex = (
        ({ crypto: { subtle }, TextEncoder }) =>
        (message) =>
          subtle
            .digest("SHA-256", new TextEncoder().encode(message))
            .then((arrayBuffer) =>
              Array.from(new Uint8Array(arrayBuffer))
                .map((buffer) => buffer.toString(16).padStart(2, "0"))
                .join("")
            )
      )(window /* Dependency injections */);

      signInAppScope.setCookie = (
        ({ document }) =>
        ([...keyValPair]) => {
          const now = new Date();
          const durationInDays = 7;
          const expiry = new Date(
            now.getTime() + durationInDays * 24 * 60 * 60 * 1000
          );

          document.cookie = [
            keyValPair,
            ["expires", expiry.toUTCString()],
            ["path", "/"],
          ]
            .map(([key, val]) => `${key}=${val}`)
            .join("; ");
        }
      )(window /* Dependency injections */);

      signInAppScope.HttpClient = function () {
        return (({ XMLHttpRequest }, { apiPath }) => {
          /**
           * HTTP GET via XHR
           * @param {string} path URL path
           * @param {Map<string, unknown>} headerMap headers
           * @return {Promise<Object>}
           */
          const httpGet = (path, headerMap) =>
            new Promise((resolve, reject) => {
              const xhr = new XMLHttpRequest();
              xhr.open("GET", `${apiPath}${path}`);
              if (headerMap) {
                const headerPairs = [...headerMap];
                for (const [key, val] of headerPairs) {
                  xhr.setRequestHeader(key, val);
                }
              }
              xhr.onload = () => {
                if (xhr.status === 200) {
                  try {
                    resolve(JSON.parse(xhr.response));
                  } catch (error) {
                    reject();
                  }
                  return;
                }
                reject();
              };
              xhr.onerror = reject;
              xhr.send();
            });
          return { httpGet };
        })(window, signInAppScope /* Dependency injections */);
      };

      ((
        { document, btoa, location },
        { sha256Hex, HttpClient, authPath, setCookie }
      ) => {
        const { httpGet } = new HttpClient();
        document.querySelector("form").addEventListener("submit", (event) => {
          event.preventDefault();
          const [username, password] = ["username", "password"].map(
            (name) => event.srcElement.querySelector(`[name="${name}"]`).value
          );
          sha256Hex(password)
            .then((passwordSha256Hex) => {
              const basicToken = btoa(`${username}:${passwordSha256Hex}`);
              const headerPair = ["Authorization", `Basic ${basicToken}`];
              return httpGet(authPath, new Map([headerPair])).then(
                () => headerPair
              );
            })
            .then(setCookie)
            .then(() => location.reload());
        });
      })(window, signInAppScope /* Dependency injections */);
    </script>
  </body>
</html>
```



##### Update nginx

```shell
$ nginxStop
$ nginxStart
```





# Install Docker

Docker creates `iptables` rules to implement network isolation, port publishing and filtering (ref: [link](https://docs.docker.com/engine/network/packet-filtering-firewalls/)) and destroys existing `iptables` rules. Backup existing rules before proceeding, if any.



Docker is installed from its Debian repository through the package manager, ref: [link](https://www.jeffgeerling.com/blog/2023/testing-coral-tpu-accelerator-m2-or-pcie-docker)

```shell
$ sudo apt-get install ca-certificates gnupg

$ sudo install -m 0755 -d /etc/apt/keyrings
$ curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
$ sudo chmod a+r /etc/apt/keyrings/docker.gpg
$ echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
$ sudo apt-get update
```



Install Docker dependencies

```shell
$ sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```



Verify Docker will launch when Raspberry Pi starts up

```shell
$ sudo systemctl is-enabled docker
```





# Install Web Application for the UPS

The PiSugar 3 Plus UPS is configured through a web application.



##### Download and install the web application

ref: [link](https://github.com/PiSugar/PiSugar/wiki/PiSugar-3-Series)

```shell
$ wget https://cdn.pisugar.com/release/pisugar-power-manager.sh
$ bash pisugar-power-manager.sh -c release
```



A HTTP server is launched immediately after the installation and it is automatically scheduled to launch when the Raspberry Pi starts up.

> [!TIP]
>
> Just as a reference, the launch command looks like this:
>
> ```shell
> $ /usr/bin/pisugar-server --config config.json --model PiSugar 3 --web /usr/share/pisugar-server/web --http 0.0.0.0:8421 --ws 0.0.0.0:8422 --tcp 0.0.0.0:8423 --uds /tmp/pisugar-server.sock
> ```
>
> where
>
> - `/usr/bin/pisugar-server` is the HTTP server binary
> - `/usr/share/pisugar-server/web` is the asset folder for the web application
> - port `8421` serves the assets for the web application
> - port `8422` broadcasts the real-time batter information



##### Configure reverse proxy for the UPS web application

```shell
$ sudo mkdir -p /etc/nginx/sites-available/ups-webui
$ sudo touch /etc/nginx/sites-available/ups-webui/locations.conf
$ sudo vim /etc/nginx/sites-available/ups-webui/locations.conf
```

Copy and paste:

```nginx
location /ups/ {
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_set_header X-NginX-Proxy true;

    proxy_pass http://127.0.0.1:8421/;
    proxy_redirect off;
}

location /ups/ws {
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
    proxy_set_header Host $host;

    proxy_pass http://127.0.0.1:8422;
}
```



```shell
$ sudo vim /etc/nginx/sites-enabled/main.conf
```

Append to the end of the `server` block:

```nginx
    # UPS Web UI paths
    include sites-available/ups-webui/locations.conf;
```



```shell
$ nginxStop
$ nginxStop
```



Unfortunately, the web application does not respect the "X-Ingress-Path" header. The base path needs to be fixed at the JavaScript

```shell
$ sudo vim /usr/share/pisugar-server/web/web.<hash>.js
```

Replace

```javascript
("https:" === window.location.protocol ? "wss:" : "ws:") + "//" + window.location.hostname + ":" + window.location.port + "/ws";
```

with

```javascript
("https:" === window.location.protocol ? "wss:" : "ws:") + "//" + window.location.hostname + "/sso/ups/ws";
```



##### Configure the UPS

Visit `https://<ip-address>/ups`

- sync up the RTC (real time clock) on the UPS board
- configuring the battery threshold for automatic shutdown

Note: the wss call failure will be fixed later when we setup SSO



##### Block external HTTP requests to the UPS server

This forces access to the web application to come through the HTTPS reverse proxy

```shell
$ sudo iptables -A INPUT -p tcp -s localhost --dport 8421 -j ACCEPT
$ sudo iptables -A INPUT -p tcp -s localhost --dport 8422 -j ACCEPT
$ sudo iptables -A INPUT -p tcp --dport 8421 -j DROP
$ sudo iptables -A INPUT -p tcp --dport 8422 -j DROP
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





# Install Runtime for the TPU

The USB Coral TPU has a runtime dependency that needs to be installed before use, ref: [link](https://coral.ai/docs/accelerator/get-started/#runtime-on-linux).



Add Coral's Debian repository to the package manager

```shell
$ echo "deb https://packages.cloud.google.com/apt coral-edgetpu-stable main" | sudo tee /etc/apt/sources.list.d/coral-edgetpu.list
```



Add the repository's public key to the package manager's list of trusted keys

```shell
$ curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
$ sudo apt-get update
```



Install the standard runtime for the TPU

```shell
$ sudo apt-get install libedgetpu1-std
```

Note, the `libedgetpu1-max` runtime runs at an increased frequency



Plug the TPU into a USB 3.0 hub with inline power

- plug the USB hub into a USB 3.0 port on the Raspberry Pi
- use the provided USB 3.0 cable

- if the TPU is already plugged in, remove it and re-plug it so the newly-installed `udev` rule can take effect



##### Verify the runtime

The TPU should be recognised as a USB device with the label "Global Unichip Corp"

```shell
$ lsusb
```



Derive the device path, for example, if the device is identified as `Bus 002 Device 003`, then the device path is `/dev/bus/usb/002/003`



Create a Docker file

Ref: [link](https://www.jeffgeerling.com/blog/2023/testing-coral-tpu-accelerator-m2-or-pcie-docker)

```shell
$ mkdir ~/coral-test
$ touch ~/coral-test/dockerfile
$ vim ~/coral-test/dockerfile
```

Copy and paste:

```dockerfile
FROM debian:10

WORKDIR /home
ENV HOME /home
RUN cd ~
RUN apt-get update
RUN apt-get install -y git nano python3-pip python-dev pkg-config wget usbutils curl

RUN echo "deb https://packages.cloud.google.com/apt coral-edgetpu-stable main" \
| tee /etc/apt/sources.list.d/coral-edgetpu.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN apt-get update
RUN apt-get install -y edgetpu-examples
```



Create a Docker image

```shell
$ sudo docker build -t "coral-test" ~/coral-test
$ sudo docker images
```



Run the Docker image

```shell
$ sudo docker run -it --device=<device-path> "coral-test" /bin/bash
```

- `-i` interactive
- `-t` terminal
- `--device` map device



Run an inference test inside the Docker container

```shell
$ python3 /usr/share/edgetpu/examples/classify_image.py --model /usr/share/edgetpu/examples/models/mobilenet_v2_1.0_224_inat_bird_quant_edgetpu.tflite --label /usr/share/edgetpu/examples/models/inat_bird_labels.txt --image /usr/share/edgetpu/examples/images/bird.bmp
$ exit
```

Note, the first test is likely to fail due to change of device path, run `lsusb` to see the TPU identification to change into "Google Inc." and run the test again using the updated device path





# Configure Docker image for the NVR

Frigate requires the existence of some directories, ref: [link](https://docs.frigate.video/guides/getting_started/#setup-directories)

```shell
$ mkdir -p /home/pi/frigate/storage

$ mkdir -p /home/pi/frigate/config
$ touch /home/pi/frigate/config/config.yml
$ vim /home/pi/frigate/config/config.yml
```

Copy and paste:

```yaml
mqtt:
  enabled: false
cameras: {}
```



```shell
$ touch /home/pi/frigate/docker-compose.json
$ sudo vim /home/pi/frigate/docker-compose.json
```

Copy and paste:

```json
{
  "services": {
    "frigate": {
      "container_name": "frigate",
      "privileged": true,
      "restart": "unless-stopped",
      "image": "ghcr.io/blakeblackshear/frigate:stable",
      "shm_size": "128mb",
      "devices": [
        "/dev/bus/usb:/dev/bus/usb",
        "/dev/video11:/dev/video11"
      ],
      "volumes": [
        "/etc/localtime:/etc/localtime:ro",
        "/home/pi/frigate/config:/config",
        "/home/pi/frigate/storage:/media/frigate",
        {
          "type": "tmpfs",
          "target": "/tmp/cache",
          "tmpfs": {
            "size": 1000000000
          }
        }
      ],
      "environment": [
        "TZ=America/New_York"
      ],
      "ports": [
        "127.0.0.1:5000:5000"
      ]
    }
  }
}
```



##### `restart`

`unless-stopped` ensures that the container will be automatically restarted on system reboot unless it was explicitly stopped (*i.e.* `docker compose down`)



##### `image`

`ghcr.io/blakeblackshear/frigate:stable` checks out a tag that is customised for the Raspberry Pi, ref: [link](https://docs.frigate.video/frigate/installation/#docker)



##### `shm_size` 

Frigate caches log and raw decoded frames in the shared memory, ref: [link](https://docs.frigate.video/frigate/installation/#storage)

- it makes sense to cache in `/dev/shm` because, the GPU also operate in the shared memory for hardware decoding
- it is not recommended to modify this directory or map it with docker

The default `shm-size` provided by Docker is 64 MB. Frigate provides a formula to estimate the minimum size (ref: [link](https://docs.frigate.video/frigate/installation/#calculating-required-shm-size)):

```python
# Example for eight cameras detecting at 1280x720, including logs
$ python -c 'print("{:.2f}MB".format(((1280 * 720 * 1.5 * 9 + 270480) / 1048576) * 8 + 30))'
# result: 126.99MB
```

- the size of the log maxes out at 30 MB



##### USB `device`

`/dev/bus/usb:/dev/bus/usb` maps all USB devices on the Raspberry Pi to the Docker container



##### hardware acceleration `device`

`/dev/video11:/dev/video11` maps the H.264 hardware accelerator on the Raspberry Pi to the Docker container, to verify (ref: [link](https://www.restack.io/p/frigate-answer-raspberry-pi-4-performance-cat-ai)):

```shell
$ for d in /dev/video*; do echo -e "---\n$d"; v4l2-ctl --list-formats-ext -d $d; done
```

```
/dev/video11
ioctl: VIDIOC_ENUM_FMT
        Type: Video Capture Multiplanar

        [0]: 'H264' (H.264, compressed)
                Size: Stepwise 32x32 - 1920x1920 with step 2/2
        [1]: 'MJPG' (Motion-JPEG, compressed)
                Size: Stepwise 32x32 - 1920x1920 with step 2/2
```



##### timezone `volume`

`/etc/localtime:/etc/localtime:ro` maps the timezone on the Raspberry Pi to the Docker container



##### configuration `volume`

`/home/pi/frigate/config:/config` maps the configuration directory on the Raspberry Pi to the Docker container



##### storage `volume`

`/home/pi/frigate/storage:/media/frigate` maps the storage directory on the Raspberry Pi to the Docker container



##### RAM disk `volume`

Frigate caches recording segments in the `/tmp/cache` volume before assembling recording in mp4 format (and storing the mp4 output file in the `/media/frigate` volume). Frigate also uses this directory for video concatenation. This volume is to be mapped to a RAM disk (tmpfs) to reduce wear on the storage device.



The general rule of thumb is to allocate at least 1 GB for each video stream to ensure smooth performance



##### `TZ` environment variable

`"TZ=America/New_York"` sets the timezone to eastern time



##### Unauthenticated `port`

`"127.0.0.1:5000:5000"` maps the port (5000) on the Raspberry Pi to the Docker container (ref: [link](https://docs.frigate.video/frigate/installation/#ports)), this port

- blocks access from all physical network interfaces on the host
- allows access from within the host
- exposes API end points and UI
- does not authenticate
- will be configured as upstream for the (authenticated) reverse-proxy
- will be configured as localhost-only





# Install and run the NVR

Docker supports both yaml and json, ref: [link](https://dockerlabs.collabnix.com/intermediate/workshop/DockerCompose/Lab_%2324_Use_JSON_instead_of_YAML_compose_file_in_Docker.html#bringup-the-container-and-run-as-daemon)

```shell
$ sudo chown -R root:root /home/pi/frigate/
$ sudo docker compose -f /home/pi/frigate/docker-compose.json up -d
$ sudo docker compose -f /home/pi/frigate/docker-compose.json ps
```

note, use the `down` and `up`option to restart container if needed



##### Configure reverse proxy for the NVR web application

```shell
$ sudo mkdir -p /etc/nginx/sites-available/nvr-webui
$ sudo touch /etc/nginx/sites-available/nvr-webui/locations.conf
$ sudo vim /etc/nginx/sites-available/nvr-webui/locations.conf
```

Copy and paste:

```nginx
location /nvr/ {
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_set_header X-NginX-Proxy true;
    proxy_set_header X-Ingress-Path "/sso/nvr";

    proxy_pass http://127.0.0.1:5000/;
    proxy_redirect off;
}

location /nvr/ws {
    proxy_http_version 1.1;
    
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
    proxy_set_header Host $host;
    
    proxy_pass http://127.0.0.1:5000/ws;
}

location /nvr/live/ {
    proxy_http_version 1.1;
    
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
    proxy_set_header Host $host;
    
    proxy_pass http://127.0.0.1:5000/live/;
}
```



```shell
$ sudo vim /etc/nginx/sites-enabled/main.conf
```

Append to the end of the `server` block:

```nginx
    # NVR Web UI paths
    include sites-available/nvr-webui/locations.conf;
```



```shell
$ nginxStop
$ nginxStop
```



##### 

# Configure the NVR

Using Hikvision camera as an example

```shell
$ sudo touch /home/pi/frigate/config.json
$ sudo vim /home/pi/frigate/config.json
```

Copy and paste:

```json
{
  "mqtt": {
    "enabled": false
  },
  "cameras": {
    "door_bell": {
      "detect": {
        "width": 704,
        "height": 576,
        "fps": 5
      },
      "ffmpeg": {
        "inputs": [
          {
            "path": "rtsp://<username>:<password>@<camera_ip_address>/<main_stream_path>",
            "roles": [
              "record"
            ]
          },
          {
            "path": "rtsp://<username>:<password>@<camera_ip_address>/<sub_stream_path>",
            "roles": [
              "detect"
            ]
          }
        ]
      }
    }
  },
  "detectors": {
    "coral": {
      "type": "edgetpu",
      "device": "usb"
    }
  },
  "ffmpeg": {
    "hwaccel_args": "preset-rpi-64-h264"
  },
  "record": {
    "enabled": true,
    "retain": {
      "days": 84,
      "mode": "motion"
    }
  },
  "snapshots": {
    "enabled": true,
    "retain": {
      "default": 84
    },
    "timestamp": true
  },
  "auth": {
    "enabled": false
  }
}
```



##### rtsp streams

figure out rtsp stream parameters (ref: [link](https://docs.frigate.video/configuration/camera_specific))

- credentials
- IP address
- use the main stream for recording
- use the sub stream for detection



##### edge detector

the `edgetpu` detector type is configured to utilise the Coral USB TPU under `/dev/bus/usb`



##### video hardware acceleration

the `preset-rpi-64-h264` preset utilises the video hardware acceleration at `/dev/video11`



##### authentication

since the reverse proxy uses the unauthenticated port `5000` instead of the authenticated port `8971` (ref: [link](https://docs.frigate.video/configuration/authentication)), there is no need to enable the authentication feature



Validate and save configuration

```shell
$ curl -X POST http://127.0.0.1:5000/api/config/save --data @/home/pi/frigate/config.json
```

Restart Frigate

```shell
$ sudo docker compose -f /home/pi/frigate/docker-compose.json down
$ sudo docker compose -f /home/pi/frigate/docker-compose.json up -d
```





# reverse proxy router

