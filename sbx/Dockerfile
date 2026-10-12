# syntax=docker/dockerfile:1
FROM docker/sandbox-templates:claude-code-docker

USER root

# Layer 1: system packages (ruby build deps, postgres, misc tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        autoconf \
        pkg-config \
        libssl-dev \
        libyaml-dev \
        zlib1g-dev \
        libffi-dev \
        libgmp-dev \
        libreadline-dev \
        libpq-dev \
        sqlite3 \
        netcat-openbsd \
        locales \
        mg \
    && rm -rf /var/lib/apt/lists/*

# Layer 2: ruby, compiled with ruby-build into /usr/local
ARG RUBY_VERSION=4.0.7
RUN git clone --depth 1 https://github.com/rbenv/ruby-build.git /tmp/ruby-build \
    && PREFIX=/usr/local /tmp/ruby-build/install.sh \
    && ruby-build ${RUBY_VERSION} /usr/local \
    && rm -rf /tmp/ruby-build

ARG BUNDLER_VERSION=4.0.4
RUN gem install bundler -v ${BUNDLER_VERSION}

USER root

# Gems install into the agent's home, no sudo needed
ENV GEM_HOME=/home/agent/.gem \
    BUNDLE_PATH=/home/agent/.gem \
    PATH=/home/agent/.gem/bin:/home/agent/.local/bin:/usr/local/share/npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Allow agent to run postgres-related commands as root/postgres without password
RUN echo "agent ALL=(root) NOPASSWD: /bin/mkdir, /bin/chown, /bin/chmod" >> /etc/sudoers && \
    echo "agent ALL=(postgres) NOPASSWD: /usr/lib/postgresql/*/bin/pg_ctl" >> /etc/sudoers

# Set default user for exec sessions
USER agent
