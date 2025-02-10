A sample learning.

#check docker GPU settings
docker run -it --gpus=all --rm nvcr.io/nvidia/k8s/cuda-sample:nbody nbody -benchmark

docker-compose up

 docker-compose exec -it ollama bash
 ollama pull all-minilm
 ollama pull llama3
 ollama run llama3
 
root@ollama:/# ollama ps
NAME             ID              SIZE      PROCESSOR          UNTIL
llama3:latest    365c0bd3c000    5.9 GB    12%/88% CPU/GPU    3 minutes from now
