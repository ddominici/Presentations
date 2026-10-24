# StackOverflow Embeddings SQL Demo

## Overview

This project demonstrates how to set up and use SQL Server with vector embeddings, including:
- Restoring the StackOverflow sample database
- Generating and storing text embeddings using external models (Ollama)
- Load balancing and performance testing with Nginx

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Ollama

### Setup

1. **Clone the repository**

   ```sh
   git clone https://github.com/your/repo.git
   cd ollama-lb-sql
   ```

2. **Restore the StackOverflow Database**

   The `restore_stackoverflow.sql` script attaches the database files.  
   Make sure the MDF/NDF/LDF files are present in `/var/opt/mssql/data/` inside the SQL Server container.

   ```sql
   CREATE DATABASE StackOverflow_Embeddings_Small
   ON 
       (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_1.mdf'),
       (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_2.ndf'),
       (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_3.ndf'),
       (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_4.ndf')
   LOG ON
       (FILENAME = N'/var/opt/mssql/data/StackOverflow2013_log.ldf')
   FOR ATTACH ;
   ```

3. **Start the Services**

   ```sh
   docker compose up -d
   ```

   This will start:
   - SQL Server
   - Nginx load balancer
   - Certificate generator

4. **Configure Nginx for Connection Pooling**

   The `nginx.conf` is set up for high concurrency and connection pooling.  

   Key settings:
   - `keepalive 256;` in the `upstream` block
   - `proxy_set_header Connection "";` in each `location` block

5. **Generate Embeddings**

   Use the provided T-SQL scripts (see `vector-demos.sql`) to generate and store embeddings via the external model endpoints.

6. **Load Testing**

   Use `test.ps1` to simulate concurrent API calls and measure performance.

   ```sh
   pwsh ./test.ps1
   ```

   Adjust `$totalWork` and `$threads` in the script as needed.

