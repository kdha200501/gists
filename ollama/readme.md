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





# Run Ollama and Open WebUI from docker compose

##### Create directories for docker volumes

```shell
$ sudo mkdir -p /opt/ollama/llm-cache
$ sudo mkdir -p /opt/ollama/open-webui
```



##### Create docker compose

```shell
$ sudo mkdir -p /opt/ollama/docker
$ cd /opt/ollama/docker

$ sudo touch docker-compose.yml
$ sudo vim docker-compose.yml
```

Copy and paste:

```yaml
networks:
  ollama_network:
    driver: bridge

services:
  ollama:
    image: ollama/ollama:0.33.3-rocm
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
      - OLLAMA_LOAD_TIMEOUT=30m
      - OLLAMA_KEEP_ALIVE=18h
      - OLLAMA_FLASH_ATTENTION=1
      - OLLAMA_KV_CACHE_TYPE=q4_0
      - OLLAMA_CONTEXT_LENGTH=196608
      - OLLAMA_NUM_PARALLEL=1
      - GPU_MAX_HW_QUEUES=1
      - OLLAMA_PRESERVE_THINKING=1
      - OLLAMA_SCHED_SPREAD=1
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
> - Update the ollama image to the desired tag
>   - pining the ollama version to avoid `0.30.x` tags, these versions have memory management issues that cause LLMs to forget progress
> - Ollama Environment Variables:
>   - `CUDA_VISIBLE_DEVICES`: Specifies which GPU(s) to use (e.g., `0`).
>   - `OLLAMA_LOAD_TIMEOUT`: Time allowed for model loading (e.g., `30m`). On ROCm/gfx1100, HIP kernel compilation after tensor loading can take 10-30+ minutes for large MoE models, exceeding Ollama's default 5-minute timeout.
>   - `OLLAMA_KEEP_ALIVE`: How long the model stays in memory (e.g., `18h`).
>   - `OLLAMA_FLASH_ATTENTION`: Enables Flash Attention because it's a prerequisite for KV quantization.
>   - `OLLAMA_KV_CACHE_TYPE`: Sets the quantization type for the KV cache (e.g., `q4_0`).
>   - `OLLAMA_CONTEXT_LENGTH`: Sets the maximum context window size (e.g. `196608` is between 130,000 and 150,000 words).
>   - `OLLAMA_NUM_PARALLEL`: Number of parallel requests the server can handle (e.g., `1` is serial).
>   - `GPU_MAX_HW_QUEUES`: Number of hardware queue per GPU device. The AMD ROCm runtime to using a single. Restricts ROCm runtime to using a single hardware queue per GPU device prevents the runtime from over-allocating parallel hardware queues, resolving the stuck idle state.
>   - `OLLAMA_PRESERVE_THINKING`: Ensures thinking process is preserved in the output.
>   - `OLLAMA_SCHED_SPREAD`: Helps in spreading the workload across available compute units during a spillover.



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



##### Run Ollama and Open WebUI

```shell
$ cd /opt/ollama/docker

$ nohup docker compose pull > $HOME/pull_ollama_log.txt 2>&1 &
$ tail -f $HOME/pull_ollama_log.txt
```



##### Run Ollama and Open WebUI at startup

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

Test the service:

```shell
$ sudo systemctl daemon-reexec
$ sudo systemctl start ollama.service
$ docker ps
```

Launch service at startup

```shell
$ sudo systemctl enable ollama.service
```







##### Update Ollama and Open WebUI

```shell
$ cd /opt/ollama/docker

$ docker compose down
$ sudo vim docker-compose.yml

$ nohup docker compose pull > $HOME/pull_ollama_log.txt 2>&1 &
$ tail -f $HOME/pull_ollama_log.txt

$ docker compose up -d

$ docker images
$ docker rmi <docker-image>
```





# Pull LLMs

```shell
$ nohup docker exec ollama-rocm ollama pull qwen3.8:27b > $HOME/ollama_pull.log 2>&1 &
```

> [!TIP]
>
> See available models at https://ollama.com/library

Find LLM setup example in OpenCode [installation](./coding-agent.md)



##### Monitor GPU stats

```shell
$ watch -n 1 rocm-smi
```



##### Identify CPU offloading

```shell
$ docker exec ollama-rocm ollama ps
```

> [!TIP]
>
> Adjust the `OLLAMA_CONTEXT_LENGTH` environment variable so that there is no split between CPU and GPU





# Connect Coding Agents to Ollama

See [coding-agent.md](coding-agent.md) for installing and configuring Claude Code and Opencode.

See [ollama-proxy.md](ollama-proxy.md) for setting up a compatibility proxy server that allows Claude Code use a wide range of models.

> [!TIP]
>
> As of June 20, 2026, Claude Code sends model names from all tiers to the API causing Ollama to throw API Error. The quick fix is to use this proxy and put the local LLM name across all tiers.
