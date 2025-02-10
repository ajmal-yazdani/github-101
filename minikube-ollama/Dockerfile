FROM nvidia/cuda:12.5.0-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN echo "==> Upgrading and installing system utilities ...." \
 && apt-get update && apt-get install -y --no-install-recommends \
    wget \
    sudo \
    python3 \
    python3-pip \
    dos2unix \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN echo "==> Installing Python packages ...." \
 && pip install --no-cache-dir streamlit requests

# Set the working directory
WORKDIR /app

# Copy the required files and directories into the working directory
COPY my_app.py /app/
COPY /scripts /scripts/

RUN echo "==> Convert script..." \
  && dos2unix /scripts/startup.sh

CMD ["/bin/bash", "/scripts/startup.sh"]