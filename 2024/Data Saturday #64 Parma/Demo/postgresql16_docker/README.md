# PostgreSQL: il query optimizer in dettaglio

L'obiettivo di questa sessione è quello di mostrare come funziona il query optimizer
di PostgreSQL.

## Setup

### Docker

Assumendo che abbiate già Docker installato, è sufficiente lanciare docker compose up per far partire il container.

Per usare l'autenticazione SSL occorre copiare il certificato generato automaticamente nel Dockerfile
nella macchina da cui ci si connette a Postgres.

Si può fare con il comando:

docker cp postgres_db:/etc/postgresql/ssl/server.crt ./server.crt

oppure usando il pulsante download da Docker desktop andando nella sezione Volumes e cliccando sul nome del volume dei certificati (postgresql16_docker_ssl_certs). Da qui cliccare con il tasto destro su
server.crt e scegliere Save As, quindi salvarlo sul proprio computer.

Una volta scaricato il file, aggiungerlo alla stringa di connessione in questo modo:

postgresql://postgres:mysecretpassword@localhost:5432/demo?sslmode=verify-full&sslcert=/path/to/server.crt


### Restore del database postgres_air2023

docker exec -i postgres_165 psql -U postgres -d postgres_air < ./backup/postgres_air_2023.sql