ARG DEBIAN_VERSION=bullseye-slim
ARG DOCKER_VERSION=20.10.6
ARG DOCKER_COMPOSE_VERSION=alpine-1.29.1
ARG GOLANG_VERSION=1.16

FROM docker:${DOCKER_VERSION} AS docker-cli
FROM docker/compose:${DOCKER_COMPOSE_VERSION} AS docker-compose

FROM golang:${GOLANG_VERSION}-buster AS gobuilder
ENV CGO_ENABLED=0
WORKDIR /githubcli
ARG GITHUBCLI_VERSION=v1.9.2
RUN git clone --branch ${GITHUBCLI_VERSION} --single-branch --depth 1 https://github.com/cli/cli.git .
RUN make && \
    chmod 500 bin/gh

FROM debian:${DEBIAN_VERSION}
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=local
LABEL \
    org.opencontainers.image.authors="quentin.mcgaw@gmail.com" \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.version=$VERSION \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.url="https://github.com/qdm12/basedevcontainer" \
    org.opencontainers.image.documentation="https://github.com/qdm12/basedevcontainer" \
    org.opencontainers.image.source="https://github.com/qdm12/basedevcontainer" \
    org.opencontainers.image.title="Base Dev container Debian" \
    org.opencontainers.image.description="Base Debian development container for Visual Studio Code Remote Containers development"
ENV BASE_VERSION="${VERSION}-${BUILD_DATE}-${VCS_REF}"

# CA certificates
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -r /var/cache/* /var/lib/apt/lists/*

# Timezone
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends tzdata && \
    rm -r /var/cache/* /var/lib/apt/lists/*
ENV TZ=

# Setup Git and SSH
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends git openssh-client && \
    rm -r /var/cache/* /var/lib/apt/lists/*

# Setup shell
ENTRYPOINT [ "/bin/zsh" ]
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends zsh nano locales && \
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -r /var/cache/* /var/lib/apt/lists/*
ENV EDITOR=nano \
    LANG=en_US.UTF-8 \
    # MacOS compatibility
    TERM=xterm
RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf && \
    locale-gen en_US.UTF-8
RUN usermod --shell /bin/zsh root
COPY shell/.p10k.zsh shell/.zshrc shell/.welcome.sh /root/
ARG POWERLEVEL10K_VERSION=v1.14.6
RUN git clone --single-branch --depth 1 https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh && \
    git clone --branch ${POWERLEVEL10K_VERSION} --single-branch --depth 1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k && \
    rm -rf ~/.oh-my-zsh/custom/themes/powerlevel10k/.git

# Docker
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-compose /usr/local/bin/docker-compose /usr/local/bin/docker-compose
ENV DOCKER_BUILDKIT=1 \
    COMPOSE_DOCKER_CLI_BUILD=1

# Github CLI
COPY --from=gobuilder /githubcli/bin/gh /usr/local/bin/gh

USER ${USERNAME}
