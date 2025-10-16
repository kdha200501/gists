# Ubuntu and kernel versions

##### kernel

```shell
$ uname -r
```

Example output:

```
6.8.0-85-generic
```

##### OS

```shell
$ lsb_release -a
```

Example output:

```
No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 24.04.3 LTS
Release:        24.04
Codename:       noble
```

> [!NOTE]
>
> `rocm` supports `6.8 [GA], 6.14 [HWE]` at `Ubuntu 24.04.3`





# Verify disk space

```shell
$ df -h
$ sudo vgdisplayc
```

> [!WARNING]
>
> Ubuntu does not necessarily use all the available disk space



##### Claim unused disk space (if any)

```shell
$ sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
$ sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
```





# Install `amdgpu` driver and the `rocm` backend

```shell
$ wget https://repo.radeon.com/amdgpu-install/7.0.2/ubuntu/noble/amdgpu-install_7.0.2.70002-1_all.deb
$ sudo apt install ./amdgpu-install_7.0.2.70002-1_all.deb
$ sudo apt update

$ sudo apt install "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
$ sudo apt install amdgpu-dkms

$ sudo apt install python3-setuptools python3-wheel
$ sudo usermod -a -G render,video $LOGNAME
$ sudo apt install rocm

$ sudo reboot
```





# Install `Docker`

```shell
$ sudo apt install apt-transport-https ca-certificates curl software-properties-common
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
$ echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

$ sudo apt update
$ sudo apt install docker-ce docker-ce-cli containerd.io
$ sudo docker --version

$ sudo usermod -aG docker $USER
$ newgrp docker
```





# Run `ollama` server from docker compose

```shell
$ docker pull "ollama/ollama:rocm"

$ sudo mkdir -p /opt/ollama/llm-cache

$ sudo mkdir -p /opt/ollama/docker
$ sudo touch /opt/ollama/docker/docker-compose.yml
$ sudo vim /opt/ollama/docker/docker-compose.yml
```

Copy and paste:

```yaml
services:
  ollama:
    image: ollama/ollama:rocm
    container_name: ollama-rocm
    restart: unless-stopped
    ports:
      - "11434:11434"
    devices:
      - /dev/kfd
      - "${ROCM_RENDER_NODE}"
    volumes:
      - /opt/ollama/llm-cache:/root/.ollama
    command: serve
```



##### Find the PCIe address for the GPU

```shell
$ lspci | grep VGA
```

Example output:

```
04:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Navi 31 [Radeon RX 7900 XT/7900 XTX/7900M] (rev c8)
```

> [!NOTE]
>
> `04:00.0` is the PCIe bus address



##### Address environment variables

```shell
$ sudo touch /opt/ollama/docker/env.sh
$ sudo chmod +x /opt/ollama/docker/env.sh
$ sudo vim /opt/ollama/docker/env.sh
```

Copy and paste:

```shell
#!/bin/bash

PCIE_ADDRESS=<pcie-address>
BASE=/dev/dri/by-path

ROCM_RENDER_NODE=$(for f in "$BASE"/*; do
  [[ "$f" != *"$PCIE_ADDRESS"* || "$f" != *render* ]] && continue
  readlink -f "$f"
done | head -n1)

cat > /opt/ollama/docker/.env <<EOF
ROCM_RENDER_NODE=$ROCM_RENDER_NODE
CUDA_VISIBLE_DEVICES=0
OLLAMA_KEEP_ALIVE=14400
EOF
```

> [!IMPORTANT]
>
> replace `<pcie-address>` with the actual PCIe address



##### Create a service for the `ollama` server

```shell
$ sudo touch /etc/systemd/system/ollama.service
$ sudo vim /etc/systemd/system/ollama.service
```

Copy and paste:

```shell
[Unit]
Description=Start Ollama via Docker Compose
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStartPre=/opt/ollama/docker/env.sh
ExecStart=/usr/bin/docker compose -f /opt/ollama/docker/docker-compose.yml up -d
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```

Test it out:

```shell
$ sudo systemctl daemon-reexec
$ sudo systemctl start ollama.service
$ docker ps
```



##### Pull a LLM

```shell
$ docker exec ollama-rocm nohup ollama pull qwen3-coder:30b > $HOME/ollama_pull.log 2>&1 & disown
$ tail -f $HOME/ollama_pull.log
```

> [!TIP]
>
> The `qwen2.5-coder` variants are incompatible with `read_file` tool calling
>
> The `qwen3-coder` variants are compatible with `read_file` tool calling
>
> See available models at https://ollama.com/library



##### Monitor GPU stats

```shell
$ watch -n 1 rocm-smi
```



##### Start the `ollama` server at boot

```shell
$ sudo systemctl enable ollama.service
```





# Configure `Continue` coding agent for ollama

```shell
$ touch "$HOME/.continue/config.yaml"
$ atom "$HOME/.continue/config.yaml"
```

Copy and paste:

```yaml
name: Local Agent
version: 1.0.0
schema: v1
models:
  - name: Qwen3 Coder 30b
    provider: ollama
    model: qwen3-coder:30b
    apiBase: http://<ip-address>:11434
    roles:
      - chat
      - edit
      - apply
      - autocomplete
```





# [Optional] Configure `ollama-code-cli` for ollama

> [!NOTE]
>
> `ollama-code-cli` is a wrapper of the `Ollama Python Client` library (ref: [link](https://github.com/ollama/ollama-python)), `ollama-code-cli` provides tool calling.

##### Install the client

```shell
$ pip install ollama-code-cli
$ atom ~/.bashrc
```

Add:

```shell
export OLLAMA_HOST=http://<ip-address>:11434
alias ollama='ollama-code-cli --model qwen3-coder:30b'
```



##### Run the client

```shell
$ ollama
```





# [Optional] Configure `ollama-code` for ollama

> [!WARNING]
>
> `ollama-code` is a fork of `qwen-code` (ref: [link](https://github.com/QwenLM/qwen-code)) which is a fork of `gemini-cli` (ref: [link](https://github.com/google-gemini/gemini-cli)), `ollama-code` inherits tool calling, and tool callings are handles it incorrectly. For example, when the model calls the read_file tool, this client fails to generate the absolute path, and when given the absolute path, the path is misinterpreted as a HTTP URL

##### Install the client

```shell
$ npm install -g @tcsenpai/ollama-code
$ atom ~/.bashrc
```
Add:

```shell
export OLLAMA_BASE_URL="http://<ip-address>:11434/v1"
export OLLAMA_API_KEY="dummy"
export OLLAMA_MODEL="qwen3-coder:30b"
```

> [!TIP]
>
> Ensure globally installed `npm` packages are in the path
>
> ```shell
> $ export PATH="$PATH:$(npm config get prefix)/bin"
> ```



##### Run the client

```shell
$ ollama-code
```

