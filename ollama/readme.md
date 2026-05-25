# Prerequisites

See [prerequisites.md](prerequisites.md) for Ubuntu/kernel version checks, disk space verification, and `amdgpu`/`rocm` driver installation.






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

##### Pull *Ollama* docker image specifically for `rocm`

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



##### Pull docker image for an Chat Webapp

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



##### Create a service for the *Ollama* server

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

Some *Ollama* models work with *Claude Code* right out-of-box because their contributors made the effort to calibrate the templates for *thinking* and local tool calling.



The *Qwopus* family of models distil *thinking* from an *Opus* model and apply to a *Qwen* model. The `gag0/qwen35-opus-distil:27b` model is simply outstanding in *thinking* and local tool calling.

```shell
 $ nohup docker exec ollama-rocm ollama pull gag0/qwen35-opus-distil:27b > ollama_hf_pull.log 2>&1 &
```



The `glm-4.7-flash` is also great at local tool calling

```shell
$ nohup docker exec ollama-rocm ollama pull glm-4.7-flash > $HOME/glm_pull.log 2>&1 &
```

> [!TIP]
>
> See available models at https://ollama.com/library
>
> For pulling LLM from hugging face, see the [unsloth/qwen3.6:27bn.md](unsloth-qwen3.6:27bn.md) example



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



# Connect Coding Agents to Ollama

See [coding-agent.md](coding-agent.md) for installing and configuring Claude Code CLI and Opencode.
