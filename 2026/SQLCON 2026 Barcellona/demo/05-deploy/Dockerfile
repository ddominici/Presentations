# The published DAB image, plus your configuration. That is the whole build.
# The connection string is NOT baked in: dab-config.json references @env('DATABASE_CONNECTION_STRING'),
# which is supplied at run time.
FROM mcr.microsoft.com/azure-databases/data-api-builder:latest

COPY dab-config.json /App/dab-config.json

# The engine listens on 5000. Nothing else to configure.
EXPOSE 5000
