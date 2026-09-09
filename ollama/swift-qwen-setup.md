##### Pull the model

```shell
$ nohup docker exec ollama-rocm ollama pull smtek/Swift-Qwen3.8-27B:Q4_K_M  > $HOME/ollama_pull.log 2>&1 &
```



##### Fix content length

The model has a limit of 140k content length. Modify this limit to make full use of the VRAM.

```shell
$ sudo vim /opt/ollama/llm-cache/Modelfile
```

Copy and paste:

```dockerfile
FROM smtek/Swift-Qwen3.8-27B:Q4_K_M
PARAMETER num_ctx 262144
```



##### Create a model wrapper

```shell
$ docker exec -it ollama-rocm ollama create swift-qwen3.8:27b-256k -f /root/.ollama/Modelfile
$ docker exec ollama-rocm ollama list
```

