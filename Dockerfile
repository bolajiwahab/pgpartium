FROM python:3.14-slim-bookworm@sha256:23c59390fc717bf09f9336908199a0ae75d9c4264bf296123f94ad772fea3b52 AS build

# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=4.45.1
ARG TARGETOS
ARG TARGETARCH

ENV LC_ALL=C.UTF-8 LANG=C.UTF-8

# Install OS dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends wget git ca-certificates gnupg2 sudo \
    # Install GitHub CLI
    && mkdir -p -m 755 /etc/apt/keyrings \
    && wget --quiet -O- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    # Install yq
    && yq_binary="yq_${TARGETOS}_${TARGETARCH}" \
    && wget --quiet "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/${yq_binary}" --output-document=/usr/bin/yq \
    && wget --quiet "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/checksums" --output-document=/tmp/yq-checksums \
    && yq_sha256="$(awk -v binary="${yq_binary}" '$1 == binary {print $19}' /tmp/yq-checksums)" \
    && test -n "${yq_sha256}" \
    && echo "${yq_sha256}  /usr/bin/yq" | sha256sum --check --strict \
    && rm /tmp/yq-checksums \
    && chmod +x /usr/bin/yq \
    # Configure git, ensure it can operate on the mounted working directory,
    # and exclude the local formatting cache globally from commits.
    && git config --system --add safe.directory '*' \
    && echo '.pgrubic_cache/' > /etc/gitexclude \
    && git config --system core.excludesFile /etc/gitexclude \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY src/requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip -r requirements.txt

# Create a non-root os user with sudo permissions, necessary to install postgresql and create a cluster.
ARG PGP_OS_USER=pgpuser

RUN useradd --uid 10001 --home-dir /src --create-home --shell /bin/bash ${PGP_OS_USER} \
    && chown -R "${PGP_OS_USER}:${PGP_OS_USER}" /src \
    && { \
         echo "${PGP_OS_USER} ALL=(ALL) NOPASSWD:ALL"; \
         echo "Defaults:${PGP_OS_USER} !secure_path"; \
         echo "Defaults:${PGP_OS_USER} !env_reset"; \
       } > /etc/sudoers.d/${PGP_OS_USER} \
    && chmod 0440 /etc/sudoers.d/${PGP_OS_USER}

ADD https://salsa.debian.org/postgresql/postgresql-common/-/raw/06f0ef8f6d30a2f6f272498c37db3689dfb8696d/pgdg/apt.postgresql.org.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/apt.postgresql.org.sh

COPY src/createcluster.conf /etc/postgresql-common/createcluster.conf

COPY src/bin/* /usr/local/bin/

WORKDIR /src

COPY src/sql sql

COPY src/schema.json ./

CMD ["/bin/bash"]

FROM build AS test

ARG BATS_VERSION=1.14.0
ARG BATS_SHA256=bb537b70b15b732f6d8827dd6578e3d8ce166636ce1f18ea9a074184fcce9177
ARG KCOV_VERSION=43+dfsg-1~bpo12+1

# Install test dependencies: kcov and bats
RUN echo "deb http://deb.debian.org/debian bookworm-backports main" \
      > /etc/apt/sources.list.d/bookworm-backports.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
         -t bookworm-backports \
         "kcov=${KCOV_VERSION}" \
    && rm -rf /var/lib/apt/lists/* \
    && wget --quiet \
        "https://github.com/bats-core/bats-core/archive/refs/tags/v${BATS_VERSION}.tar.gz" \
        --output-document=/tmp/bats-core.tar.gz \
    && echo "${BATS_SHA256}  /tmp/bats-core.tar.gz" | sha256sum --check --strict \
    && tar -xzf /tmp/bats-core.tar.gz \
    && rm /tmp/bats-core.tar.gz \
    && bats-core-${BATS_VERSION}/install.sh /usr/local \
    && rm -rf bats-core-${BATS_VERSION}

# Test changes should not invalidate the dependency-installation layer.
COPY --chown=${PGP_OS_USER}:${PGP_OS_USER} tests tests

USER ${PGP_OS_USER}

FROM test AS test-postgres

ARG PGP_PG_MAJOR_VERSION=17

USER root

# Cache the large PostgreSQL toolchain in the version-specific test image
# instead of downloading it every time the test container starts.
# pgp-start still exercises its normal installation path, but installation is
# a no-op in this test-only image because PostgreSQL is already present.
RUN apt.postgresql.org.sh -i -p -v "${PGP_PG_MAJOR_VERSION}" \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/true /usr/local/bin/apt.postgresql.org.sh

USER ${PGP_OS_USER}

FROM build AS runtime

USER ${PGP_OS_USER}
