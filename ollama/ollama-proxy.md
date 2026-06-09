# Free Claude Code Proxy Server

A middleware proxy that routes Claude Code's Anthropic API calls to various providers (Ollama, NVIDIA NIM, OpenRouter, etc.), ref: [link](https://github.com/Alishahryar1/free-claude-code)



### Create a service

```shell
$ git clone https://github.com/Alishahryar1/free-claude-code.git ~/.free-claude-code

$ sudo mkdir -p ~/.free-claude-code/.uv_cache

$ sudo touch /etc/systemd/system/free-claude-code.service
$ sudo vim /etc/systemd/system/free-claude-code.service
```

Copy and paste:

```ini
[Unit]
Description=Free Claude Code Proxy Server
After=network.target

[Service]
Type=simple
User=<user>
WorkingDirectory=/home/<user>/.free-claude-code

# Redirect uv to a local directory instead of system /tmp
Environment=UV_CACHE_DIR=/home/<user>/.free-claude-code/.uv_cache
Environment=UV_PYTHON_INSTALL_DIR=/home/<user>/.free-claude-code/.uv_cache/python

# Bind only to localhost (127.0.0.1) — NOT 0.0.0.0 (all interfaces)
ExecStart=/home/<user>/.local/bin/uv run uvicorn server:app --host 127.0.0.1 --port 8082

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

> [!IMPORTANT]
>
> Replace `<user>` with the actual username



### Run at startup

```shell
$ sudo systemctl daemon-reload
$ sudo systemctl enable free-claude-code
$ sudo systemctl start free-claude-code

# Verify it's running and bound to localhost only
$ systemctl status free-claude-code
$ ss -tlnp | grep 8082  # Should show 127.0.0.1:8082, NOT 0.0.0.0:8082
```



### Troubleshoot SELinux Issues

If SELinux is blocking the `uv` command, then label `.free-claude-code` for execution:

```shell
# Label the uv binary and app directory for execution
$ sudo semanage fcontext -a -t bin_t "$HOME/.local/bin/uv"
$ sudo semanage fcontext -a -t httpd_sys_content_t "$HOME/.free-claude-code(/.*)?"
$ sudo restorecon -R -v ~/.local/bin/uv ~/.free-claude-code

# Restart the service
$ sudo systemctl daemon-reload
$ sudo systemctl restart free-claude-code
```

> [!NOTE]
>
> The `httpd_sys_content_t` type allows the service to read and execute files in the application directory.



### Configure model

Navigate to Admin UI at http://127.0.0.1:8082/admin to

- point `Ollama Base URL` to `http://<ip-address>:11434`
- point `MODEL` to a model served by Ollama



### Setup Claude Code

After the service is running, configure Claude Code to use the proxy:

```shell
export ANTHROPIC_BASE_URL="http://127.0.0.1:8082"
export ANTHROPIC_AUTH_TOKEN="freecc"
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY="1"
export CLAUDE_CODE_AUTO_COMPACT_WINDOW="190000"
```

Then launch Claude Code:
```shell
$ source ~/.bashrc
$ claude
```
