FROM python:3.12-slim-bookworm@sha256:4766d8b510c428e595d74b9cc5bbb2fae8e26316fffb4adc89908d79aacd58a2 AS build

ARG YQ_VERSION=4.45.1

ENV LC_ALL=C.UTF-8 LANG=C.UTF-8

# Install OS dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends wget git ca-certificates gnupg2 \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && wget --quiet -O- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Ensure Git can operate on the mounted working directory.
RUN git config --system --add safe.directory '*'

RUN wget --quiet "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" --output-document=/usr/bin/yq \
    && chmod +x /usr/bin/yq

ADD https://salsa.debian.org/postgresql/postgresql-common/-/raw/master/pgdg/apt.postgresql.org.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/apt.postgresql.org.sh

COPY src/createcluster.conf /etc/postgresql-common/createcluster.conf

COPY src/bin/* /usr/local/bin/

WORKDIR /src

# Install Python dependencies.
COPY src/requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip -r requirements.txt

COPY src/sql sql
COPY src/schema.json ./

FROM build AS test

ARG BATS_VERSION=1.14.0
ARG KCOV_VERSION=43+dfsg-1~bpo12+1

COPY tests tests

# Install kcov
RUN echo "deb http://deb.debian.org/debian bookworm-backports main" \
      > /etc/apt/sources.list.d/bookworm-backports.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
         -t bookworm-backports \
         "kcov=${KCOV_VERSION}" \
    && rm -rf /var/lib/apt/lists/*

RUN wget -qO- \
        "https://github.com/bats-core/bats-core/archive/refs/tags/v${BATS_VERSION}.tar.gz" \
    | tar -xz \
    && ./bats-core-${BATS_VERSION}/install.sh /usr/local \
    && rm -rf bats-core-${BATS_VERSION}

CMD ["/bin/bash"]

FROM build AS final

# Switch to non-root user.
USER 5000

CMD ["/bin/bash"]
