FROM mysql:8.4

# Embed init SQL scripts in the image to avoid host bind-mount issues on Windows paths.
COPY mysql/*.sql /docker-entrypoint-initdb.d/
