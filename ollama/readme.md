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
    image: ollama/ollama:0.22.1-rocm
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
      - OLLAMA_FLASH_ATTENTION=1
      - OLLAMA_KV_CACHE_TYPE=q4_0
      - OLLAMA_CONTEXT_LENGTH=32768
      - OLLAMA_NUM_PARALLEL=1
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
>   - `OLLAMA_KEEP_ALIVE`: How long the model stays in memory (e.g., `14400` for 4 hours).
>   - `OLLAMA_FLASH_ATTENTION`: Enables Flash Attention for faster inference.
>   - `OLLAMA_KV_CACHE_TYPE`: Sets the quantization type for the KV cache (e.g., `q4_0`).
>   - `OLLAMA_CONTEXT_LENGTH`: Sets the maximum context window size (e.g. `32768` is about 25,000 words).
>   - `OLLAMA_NUM_PARALLEL`: Number of parallel requests the server can handle (e.g., `1` is serial).
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

Some models on *Ollama* work with *Claude Code* right out-of-box because their contributors made the effort to calibrate the template for *thinking* and local tool calling like the `gag0/qwen35-opus-distil:27b` model.

```shell
$ nohup docker exec ollama-rocm ollama pull gag0/qwen35-opus-distil:27b > $HOME/ollama_pull.log 2>&1 &
```



The `glm-4.7-flash` is also great at local tool calling, but thinking is not its strong suit

```shell
$ nohup docker exec ollama-rocm ollama pull glm-4.7-flash > $HOME/ollama_pull.log 2>&1 &
```



Some models work with *Claude Code* out-of-box but suffers infinite loop. Sometimes, these models can be fixed by tuning the parameters through Modelfile. `gemma4:26b` is one such example ref: [link](https://www.kdnuggets.com/local-agentic-programming-on-the-cheap-claude-code-ollama-gemma4)


```shell
$ nohup docker exec ollama-rocm ollama pull gemma4:26b > $HOME/ollama_pull.log 2>&1 &
```



```
FROM gemma4:26b
PARAMETER num_ctx 131072
PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.15
PARAMETER num_predict 4096
SYSTEM """You are a senior software engineer operating as a coding agent.

When working with code:
- Read files before editing them. Never assume file contents.
- Make one focused change at a time and verify it before proceeding.
- When a tool call fails, examine the error carefully before retrying.
  Do not retry with identical parameters. Diagnose first.
- Prefer surgical edits over full file rewrites.
- Run tests after each meaningful change, not after a batch of changes.
- If you are uncertain about the codebase structure, read more files
  rather than guessing.

Be precise and methodical. Avoid explaining what you are about to do
when you could simply do it."""
```

> [!TIP]
>
> See the [unsloth/qwen3.6:27bn.md](unsloth-qwen3.6:27bn.md) example for instructions on how to build from a Modelfile




When a LLM does not work with *Claude Code*, give `OpenCode` a try

```shell
$ nohup docker exec ollama-rocm ollama pull fredrezones55/Qwopus3.6 > $HOME/ollama_pull.log 2>&1 &
```



See available models at https://ollama.com/library



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
