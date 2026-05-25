# Claude Code

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





# Opencode

##### Installation

```shell
$ curl -fsSL https://opencode.ai/install | bash
```

##### Configuration

```shell
$ touch ~/.config/opencode/opencode.json
$ vim ~/.config/opencode/opencode.json
```

Copy + paste

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://192.168.0.23:11434/v1"
      },
      "models": {
        "qwen3.6:27b": {
          "name": "qwen3.6:27b"
        }
      }
    }
  }
}
```
