FROM postgres:16

# Embed init SQL scripts in the image to avoid host bind-mount issues on Windows paths.
COPY postgresql/*.sql /docker-entrypoint-initdb.d/
