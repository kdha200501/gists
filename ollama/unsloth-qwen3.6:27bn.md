Pull the model

```shell
$ cd ~
$ nohup docker exec ollama-rocm ollama pull hf.co/unsloth/Qwen3.6-27B-GGUF:Q4_K_M > ollama_hf_pull.log 2>&1 &

$ tail -f ollama_hf_pull.log
```



After pull is successful, find the blob filename:

```shell
$ cat /opt/ollama/llm-cache/models/manifests/hf.co/unsloth/Qwen3.6-27B-GGUF/Q4_K_M | jq -r '.layers[] | select(.mediaType == "application/vnd.ollama.image.model") | .digest | gsub(":";"-")'
```

> [!TIP]
>
> The filename is formatted as `sha256-<digest>` *e.g.* `sha256-5ed60d0af4650a854b1755bd392f9aef4872643dc25a254bc68043fa638392a0`



Create a relative link inside the blobs folder

```shell
$ cd /opt/ollama/llm-cache/models/blobs/
$ sudo ln -s sha256-<digest> unsloth-qwen3_6_27bn.gguf

$ sudo touch /opt/ollama/llm-cache/Modelfile
$ sudo vim /opt/ollama/llm-cache/Modelfile
```

Copy and paste

```
# 1. Point to your locally downloaded GGUF file
FROM /root/.ollama/models/blobs/unsloth-qwen3_6_27bn.gguf

# 2. Correct Agent Parameters
PARAMETER num_ctx 32768
PARAMETER temperature 0.2
PARAMETER top_p 0.95
PARAMETER repeat_penalty 1.1

# Ensure we don't stop prematurely
PARAMETER stop "<|im_start|>"
PARAMETER stop "<|im_end|>"
PARAMETER stop "<|endoftext|>"

TEMPLATE """{{- if .System }}<|im_start|>system
{{ .System }}
{{- if .Tools }}

# Tools
You may call one or more actions. You are provided with function signatures within XML tags:
<tools>
{{- range .Tools }}
{"type": "function", "function": {{ .Function }}}
{{- end }}
</tools>

For each function call, return a JSON object with function name and arguments within <tool_call> XML tags:
<tool_call>
{"name": <tool_name>, "arguments": <args_json_object>}
</tool_call>
{{- end }}<|im_end|>
{{- end }}
{{- range .Messages }}
{{- if eq .Role "user" }}<|im_start|>user
{{ .Content }}<|im_end|>
{{- else if eq .Role "assistant" }}<|im_start|>assistant
{{- if .Content }}{{ .Content }}{{- end }}
{{- if .ToolCalls }}<tool_call>
{{- range .ToolCalls }}{"name": "{{ .Function.Name }}", "arguments": {{ .Function.Arguments }}}{{- end }}
</tool_call>{{- end }}<|im_end|>
{{- else if eq .Role "tool" }}<|im_start|>user
<tool_response>
{{ .Content }}
</tool_response><|im_end|>
{{- end }}
{{- end }}<|im_start|>assistant
"""
```



```shell
$ docker exec -it ollama-rocm ollama create qwen3.6:27b -f /root/.ollama/Modelfile
```

> [!IMPORTANT]
>
> Use an Ollama approved model name *e.g.* `qwen3.6:27b`
