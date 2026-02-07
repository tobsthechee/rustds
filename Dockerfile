FROM ubuntu:20.04

LABEL origin="Didstopia <support@didstopia.com>"
LABEL maintainer="tobychee <help@tobyworld.eu>"
LABEL isfork="Yes"

ARG DEBIAN_FRONTEND=noninteractive

# Enable i386 architecture (required for SteamCMD & Rust)
RUN dpkg --add-architecture i386

# Base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    gnupg \
    software-properties-common \
    tzdata \
    libc6 \
    libc6:i386 \
    libgcc-s1 \
    libgcc-s1:i386 \
    libstdc++6 \
    libstdc++6:i386 \
    libssl1.1 \
    libssl1.1:i386 \
    libsdl2-2.0-0:i386 \
    libgdiplus \
    nginx \
    expect \
    tcl \
    unzip \
    libarchive-tools \
    git \
    xz-utils \
    bash \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------
# Install Node.js 12 (official binary, NodeSource-free)
# --------------------------------------------------
ENV NODE_VERSION=12.22.12

RUN curl -fsSL https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz \
    | tar -xJ -C /usr/local --strip-components=1 && \
    ln -sf /usr/local/bin/node /usr/bin/node && \
    ln -sf /usr/local/bin/npm /usr/bin/npm && \
    npm install -g npm@6

# --------------------------------------------------
# Install SteamCMD
# --------------------------------------------------
RUN mkdir -p /steamcmd && \
    cd /steamcmd && \
    curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    | tar zxvf -

# --------------------------------------------------
# Nginx cleanup
# --------------------------------------------------
RUN rm -rf /usr/share/nginx/html/* && \
    rm -rf /etc/nginx/sites-available/* && \
    rm -rf /etc/nginx/sites-enabled/*

# --------------------------------------------------
# WebRCON
# --------------------------------------------------
COPY nginx_rcon.conf /etc/nginx/nginx.conf

RUN curl -sL https://github.com/Facepunch/webrcon/archive/24b0898d86706723d52bb4db8559d90f7c9e069b.zip \
    | bsdtar -xvf- -C /tmp && \
    mv /tmp/webrcon-24b0898d86706723d52bb4db8559d90f7c9e069b/* /usr/share/nginx/html/ && \
    rm -rf /tmp/webrcon-24b0898d86706723d52bb4db8559d90f7c9e069b

# --------------------------------------------------
# Custom scripts & apps
# --------------------------------------------------
ADD fix_conn.sh /tmp/fix_conn.sh

RUN mkdir -p /steamcmd/rust /var/log/nginx

ADD shutdown_app/ /app/shutdown_app/
WORKDIR /app/shutdown_app
RUN npm install

ADD restart_app/ /app/restart_app/
WORKDIR /app/restart_app
RUN npm install

ADD scheduler_app/ /app/scheduler_app/
WORKDIR /app/scheduler_app
RUN npm install

ADD heartbeat_app/ /app/heartbeat_app/
WORKDIR /app/heartbeat_app
RUN npm install

ADD rcon_app/ /app/rcon_app/
WORKDIR /app/rcon_app
RUN npm install && ln -s /app/rcon_app/app.js /usr/bin/rcon

# --------------------------------------------------
# Rust scripts & metadata
# --------------------------------------------------
ADD install.txt /app/install.txt
ADD start_rust.sh /app/start.sh
ADD update_check.sh /app/update_check.sh
COPY README.md LICENSE.md /app/

WORKDIR /

# --------------------------------------------------
# Permissions
# --------------------------------------------------
#RUN chown -R 1000:1000 \
#    /steamcmd \
#    /app \
#    /usr/share/nginx/html \
#    /var/log/nginx

#ENV PGID=1000
#ENV PUID=1000

# --------------------------------------------------
# Ports
# --------------------------------------------------
EXPOSE 8080 28015 28016 28082

# --------------------------------------------------
# Rust environment variables (unchanged)
# --------------------------------------------------
ENV RUST_SERVER_STARTUP_ARGUMENTS="-batchmode -load -nographics +server.secure 1"
ENV RUST_SERVER_IDENTITY="docker"
ENV RUST_SERVER_PORT=""
ENV RUST_SERVER_QUERYPORT=""
ENV RUST_SERVER_SEED="12345"
ENV RUST_SERVER_NAME="Rust Server [DOCKER]"
ENV RUST_SERVER_DESCRIPTION="This is a Rust server running inside a Docker container!"
ENV RUST_SERVER_URL="https://hub.docker.com/r/tobysmyki/rustds"
ENV RUST_SERVER_BANNER_URL=""
ENV RUST_RCON_WEB="1"
ENV RUST_RCON_PORT="28016"
ENV RUST_RCON_PASSWORD="docker"
ENV RUST_APP_PORT="28082"
ENV RUST_UPDATE_CHECKING="0"
ENV RUST_HEARTBEAT="0"
ENV RUST_UPDATE_BRANCH="public"
ENV RUST_START_MODE="0"
ENV RUST_OXIDE_ENABLED="0"
ENV RUST_OXIDE_UPDATE_ON_BOOT="1"
ENV RUST_RCON_SECURE_WEBSOCKET="0"
ENV RUST_SERVER_WORLDSIZE="3500"
ENV RUST_SERVER_MAXPLAYERS="500"
ENV RUST_SERVER_SAVE_INTERVAL="600"

ENV CHOWN_DIRS="/app,/steamcmd,/usr/share/nginx/html,/var/log/nginx"

CMD ["bash", "/app/start.sh"]
