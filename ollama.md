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
$ sudo vgdisplay
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





# Install Docker

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





# Run Ollama server from docker compose

##### Pull Ollama docker image specifically for `rocm`

```shell
$ nohup docker pull ollama/ollama:rocm > $HOME/pull_ollama_log.txt 2>&1 &
```

> [!TIP]
>
> Updating Ollama requires stopping and removing container and image
>
> ```shell
> $ docker ps
> $ docker stop ollama-rocm
> 
> $ docker ps -a
> $ docker rm <container-id>
> 
> $ docker images
> $ docker rmi ollama/ollama:rocm
> ```
>
> Then run the `docker pull` above



##### Pull docker image for an Ollama Webapp

```shell
$ nohup docker pull ghcr.io/open-webui/open-webui:main > $HOME/pull_open_webui_log.txt 2>&1 &
```



##### Create docker compose

```shell
$ sudo mkdir -p /opt/ollama/llm-cache
$ sudo mkdir -p /opt/ollama/open-webui

$ sudo mkdir -p /opt/ollama/docker
$ sudo touch /opt/ollama/docker/docker-compose.yml
$ sudo vim /opt/ollama/docker/docker-compose.yml
```

Copy and paste:

```yaml
networks:
  ollama_network:
    driver: bridge

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
    networks:
      - ollama_network
    environment:
      - CUDA_VISIBLE_DEVICES=0
      - OLLAMA_KEEP_ALIVE=14400
      - OLLAMA_CONTEXT_LENGTH=32768
    command: serve

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    ports:
      - "3000:8080"
    environment:
      - "OLLAMA_BASE_URL=http://ollama-rocm:11434"
    volumes:
      - /opt/ollama/open-webui:/app/backend/data
    networks:
      - ollama_network
```

> [!TIP]
>
> `OLLAMA_CONTEXT_LENGTH=32768` is a generous window (about 25,000 words)



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



##### Address dynamic environment variables

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
EOF
```

> [!IMPORTANT]
>
> replace `<pcie-address>` with the actual PCIe address



##### Create a service for the Ollama server

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



##### Pull LLMs

```shell
$ nohup docker exec ollama-rocm ollama pull qwen3-coder:30b > $HOME/qwen_pull.log 2>&1 &
$ nohup docker exec ollama-rocm ollama pull gemma3:27b > $HOME/gemma_pull.log 2>&1 &
$ nohup docker exec ollama-rocm ollama pull glm-4.7-flash > $HOME/glm_pull.log 2>&1 &
```

> [!TIP]
>
> The `qwen3-coder` variants are compatible with tool calling
>
> The `gemma3` LLM is multi modal
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



##### Identify CPU offloading

```shell
$ docker exec ollama-rocm ollama ps
```

> [!TIP]
>
> Adjust the `OLLAMA_CONTEXT_LENGTH` environment variable so that there is no split between CPU and GPU





# Connect `Continue` coding agent to Ollama

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





# Connect `Claude Code CLI` coding agent to Ollama

The Ollama API is now compatible with OpenAI and Anthropic clients

##### Installation

```shell
$ curl -fsSL https://claude.ai/install.sh | bash
```

> [!TIP]
>
> The cli is installed at `~/.local/bin/claude `



##### Configuration

```shell
$ vim ~/.bashrc
```

Copy and paste:

```shell
export ANTHROPIC_BASE_URL="http://<ip-address>:11434"
export ANTHROPIC_API_KEY="" # Required but ignored by Ollama
export ANTHROPIC_AUTH_TOKEN="ollama"
export EDITOR=vim
```



```shell
$ vim ~/.config/git/ignore
```

Add:

```
**/.claude/settings.local.json
**/.mcp.json
```



##### Launch

```shell
$ claude --model qwen3-coder:30b
```

