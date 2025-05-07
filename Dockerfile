FROM debian:bookworm-slim AS base

ADD https://salsa.debian.org/postgresql/postgresql-common/-/raw/master/pgdg/apt.postgresql.org.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/apt.postgresql.org.sh

COPY createcluster.conf /etc/postgresql-common/createcluster.conf

COPY bin/* /usr/local/bin/

WORKDIR /src

COPY sql sql

COPY schema.json schema.json

# Enable amd64 architecture in case we are running on arm64
RUN dpkg --add-architecture amd64

# Install dependencies
RUN apt-get update \
    && apt-get install -y wget python3-jsonschema=4.10.3-1 git ca-certificates gnupg2 libc6:amd64 \
    && apt-get clean \
    && rm -rf /var/cache/apt/* /var/lib/apt/lists/*

# Install GitHub CLI
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && wget --quiet -O- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt update \
    && apt install -y gh \
    && apt-get clean \
    && rm -rf /var/cache/apt/* /var/lib/apt/lists/*

# Ensure Git can do stuff in the working directory.
RUN git config --system --add safe.directory '*'

ENV LC_ALL=C.UTF-8 LANG=C.UTF-8 PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN wget --quiet https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64 --output-document=/usr/bin/yq && \
    chmod +x /usr/bin/yq

# Switch to non-root user.
USER 5000

CMD ["/bin/bash"]

FROM base AS test

COPY tests tests

COPY .shellspec .shellspec

CMD ["/bin/bash"]
