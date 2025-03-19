FROM debian:bookworm-slim AS pgpartium

ADD https://salsa.debian.org/postgresql/postgresql-common/-/raw/master/pgdg/apt.postgresql.org.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/apt.postgresql.org.sh

COPY createcluster.conf /etc/postgresql-common/createcluster.conf

COPY bin/* /usr/local/bin/

# RUN chmod +x /usr/local/bin/partium

WORKDIR /app

COPY sql sql

# Install apt dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends yq python3-yaml python3-jsonschema python3-psycopg2 ca-certificates gnupg2 sudo \
    && apt-get clean \
    && rm -rf /var/cache/apt/* /var/lib/apt/lists/*

ENV LC_ALL=C.UTF-8 LANG=C.UTF-8 PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Add non-root user
RUN useradd pgpartium && adduser pgpartium sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER pgpartium

CMD ["/bin/bash"]
