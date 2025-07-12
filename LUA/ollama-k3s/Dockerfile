FROM ollama/ollama:latest

# Set environment variables
ENV OLLAMA_HOST=0.0.0.0
ENV OLLAMA_NOPRUNE=true

# Install additional utilities that might be useful
# RUN apt-get update && apt-get install -y --no-install-recommends \
#     curl \
#     ca-certificates \
#     jq \
#     && rm -rf /var/lib/apt/lists/*

# Create model directory structure (will be mounted over)
RUN mkdir -p /root/.ollama/models/blobs \
    && mkdir -p /root/.ollama/models/manifests

# Add a healthcheck
# HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
#   CMD curl -f http://localhost:11434/api/version || exit 1

# Keep the original entrypoint
ENTRYPOINT ["/bin/ollama"]
CMD ["serve"]