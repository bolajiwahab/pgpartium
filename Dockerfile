FROM debian:bookworm-slim AS pgpartium

ADD https://salsa.debian.org/postgresql/postgresql-common/-/raw/master/pgdg/apt.postgresql.org.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/apt.postgresql.org.sh

COPY createcluster.conf /etc/postgresql-common/createcluster.conf

COPY bin/* /usr/local/bin/

# RUN chmod +x /usr/local/bin/partium

WORKDIR /app

COPY sql sql

COPY schema.json schema.json

# Install dependencies
RUN apt-get update \
    && apt-get install -y wget python3-jsonschema=4.10.3-1 python3-psycopg2 ca-certificates gnupg2 \
    && apt-get clean \
    && rm -rf /var/cache/apt/* /var/lib/apt/lists/*

ENV LC_ALL=C.UTF-8 LANG=C.UTF-8 PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN wget --no-verbose https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64 --output-document=/usr/bin/yq && \
    chmod +x /usr/bin/yq

# Switch to non-root user.
USER 5000

CMD ["/bin/bash"]
