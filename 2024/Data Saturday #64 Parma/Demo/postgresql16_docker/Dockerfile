# Dockerfile
FROM postgres:16.5-alpine

# Install OpenSSL
RUN apk add --no-cache openssl

# Create SSL certificates
RUN mkdir -p /etc/postgresql/ssl && \
    cd /etc/postgresql/ssl && \
    # Generate root SSL certificate
    openssl req -new -x509 -days 365 -nodes \
        -out server.crt \
        -keyout server.key \
        -subj "/C=IT/ST=Marche/L=Ancona/O=sqlserverinfo/OU=IT/CN=localhost" && \
    chmod 600 server.key && \
    chown postgres:postgres server.key server.crt

# Copy configurations
COPY init.sql /docker-entrypoint-initdb.d/
COPY postgresql.conf /etc/postgresql/postgresql.conf
COPY pg_hba.conf /etc/postgresql/pg_hba.conf

CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf", "-c", "hba_file=/etc/postgresql/pg_hba.conf"]
