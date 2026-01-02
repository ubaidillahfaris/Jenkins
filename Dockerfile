# Extend Jenkins official image, install Docker CLI + compose
FROM jenkins/jenkins:lts

USER root

# Install docker CLI (engine dari host via socket) dan dependencies
RUN apt-get update && \
    apt-get install -y docker.io curl && \
    rm -rf /var/lib/apt/lists/*

# Install docker-compose
RUN curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

# Tambahkan jenkins user ke group docker supaya bisa akses docker socket
RUN usermod -aG docker jenkins

# Set user kembali ke jenkins
USER jenkins
