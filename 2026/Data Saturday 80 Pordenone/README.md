# SQL Server 2025 + Ollama + Caddy — Setup Locale su Windows 11

> **Obiettivo:** Permettere a SQL Server 2025 di interrogare un modello LLM locale (Ollama) tramite un reverse proxy HTTPS (Caddy), tutto su un singolo PC Windows 11.

---

## Architettura

```
SQL Server 2025          Caddy (reverse proxy)        Ollama
(localhost:1433)  --->  (localhost:11443 HTTPS)  --->  (localhost:11434 HTTP)
```

SQL Server richiede HTTPS per `sp_invoke_external_endpoint`, quindi Caddy funge da bridge
tra il T-SQL e le API REST di Ollama.

---

## 1. SQL Server 2025

### Installazione

1. Scarica SQL Server 2025 (edizione **Developer**) da:  
   https://www.microsoft.com/en-us/sql-server/sql-server-downloads

2. Esegui il wizard di installazione. Nella schermata **Feature Selection** seleziona almeno:
   - Database Engine Services
   - Full-Text and Semantic Extractions for Search

3. Nella schermata **Database Engine Configuration** scegli **Mixed Mode** e imposta la password per `sa`.

### Abilita TCP/IP

1. Apri **SQL Server Configuration Manager**
2. Vai su *SQL Server Network Configuration → Protocols for MSSQLSERVER*
3. Abilita **TCP/IP**
4. Riavvia il servizio SQL Server

### Verifica

```sql
SELECT @@VERSION;
-- Deve mostrare SQL Server 2025 (versione 17.x)
```

### Abilita le chiamate HTTP esterne

```sql
EXEC sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE WITH OVERRIDE;

```

---

## 2. Ollama

### Installazione

Scarica e installa Ollama per Windows da https://ollama.com/download/windows.
Il setup crea automaticamente un servizio Windows.

### Configura l'ascolto su localhost

Di default Ollama ascolta solo su `127.0.0.1`. Verifica che la variabile d'ambiente sia:

```
OLLAMA_HOST = 127.0.0.1:11434
```

Se non è impostata, aggiungila come variabile di **sistema** (non utente):

```powershell
[System.Environment]::SetEnvironmentVariable("OLLAMA_HOST", "127.0.0.1:11434", "Machine")
```

Riavvia il servizio Ollama (o il PC) dopo la modifica.

### Scarica un modello

```powershell
ollama pull llama3.2
# oppure un modello più leggero
ollama pull phi3
```

### Verifica

```powershell
curl http://localhost:11434/api/tags
# Deve restituire un JSON con i modelli installati
```

---

## 3. OpenSSL per Windows

### Installazione

Scarica **Win64 OpenSSL v3.x.x** da: https://slproweb.com/products/Win32OpenSSL.html  
Installa in `C:\OpenSSL-Win64`. Quando chiede dove copiare le DLL, scegli *Windows system directory*.

### Aggiungi OpenSSL al PATH

```powershell
[System.Environment]::SetEnvironmentVariable(
  "Path",
  $env:Path + ";C:\OpenSSL-Win64\bin",
  "Machine"
)
```

Chiudi e riapri PowerShell, poi verifica:

```powershell
openssl version
```

---

## 4. Certificati SSL Self-Signed

Il certificato deve essere emesso per `localhost` o `127.0.0.1`, poiché tutto il traffico resta in locale.

### Genera il certificato

```powershell
New-Item -ItemType Directory -Force -Path "C:\certs"
cd C:\certs

openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
  -keyout C:\certs\cert.key `
  -out C:\certs\cert.crt `
  -subj "/CN=localhost" `
  -addext "subjectAltName=IP:127.0.0.1,DNS:localhost"
```

> **Nota:** In PowerShell il carattere di continuazione riga è il backtick `` ` ``, non il backslash `\`.

### Verifica il certificato

```powershell
openssl x509 -in C:\certs\cert.crt -text -noout
# Controlla che in "X509v3 Subject Alternative Name" compaia:
# IP Address:127.0.0.1, DNS:localhost
```

### Importa il certificato come Trusted Root

> Esegui PowerShell come **Amministratore**

```powershell
Import-Certificate -FilePath "C:\certs\cert.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

Questo passaggio è obbligatorio: senza di esso SQL Server rifiuterà la connessione HTTPS.  
Puoi verificare l'importazione aprendo `certlm.msc` → *Trusted Root Certification Authorities → Certificates*.

---

## 5. Caddy

### Installazione

Scarica il binario per Windows (amd64) da https://caddyserver.com/download  
Nessun plugin aggiuntivo necessario. Copia `caddy.exe` in `C:\Caddy\`.

### Crea il Caddyfile

Crea il file `C:\Caddy\Caddyfile`:

```
{
    debug
}

localhost:11443 {
    tls "C:/certs/cert.crt" "C:/certs/cert.key"
    reverse_proxy 127.0.0.1:11434
    log {
        output stdout
    }
}
```

> I path con `/` (slash) funzionano correttamente su Windows in Caddy.

### Avvio manuale (test)

```powershell
cd C:\Caddy
.\caddy.exe run --config Caddyfile
```

Nei log dovrebbe comparire la conferma che Caddy è in ascolto su `localhost:11443`.

### Verifica il proxy

Da una nuova finestra PowerShell:

```powershell
curl -k https://localhost:11443/api/tags
```

Se vedi il JSON con i modelli Ollama, il proxy funziona correttamente.

### Installa Caddy come servizio Windows

> Esegui PowerShell come **Amministratore**

```powershell
sc.exe create Caddy binPath= "C:\Caddy\caddy.exe run --config C:\Caddy\Caddyfile" start= auto
sc.exe description Caddy "Caddy reverse proxy per Ollama"
sc.exe start Caddy
```

Per fermare o rimuovere il servizio:

```powershell
sc.exe stop Caddy
sc.exe delete Caddy
```

---

## 6. Test end-to-end da T-SQL

### Chiamata a Ollama tramite sp_invoke_external_endpoint

```sql
DECLARE @url     NVARCHAR(500) = 'https://localhost:11443/api/generate';
DECLARE @payload NVARCHAR(MAX) = N'{
    "model": "llama3.2",
    "prompt": "Ciao! Rispondimi in una sola frase.",
    "stream": false
}';

DECLARE @response NVARCHAR(MAX);

EXEC sp_invoke_external_endpoint
    @url     = @url,
    @payload = @payload,
    @method  = 'POST',
    @response = @response OUTPUT;

SELECT @response AS RispostaOllama;
```

### Parsing della risposta JSON

```sql
SELECT
    JSON_VALUE(@response, '$.response') AS Testo,
    JSON_VALUE(@response, '$.model')    AS Modello,
    JSON_VALUE(@response, '$.done')     AS Completato;
```

---

## Riepilogo porte (tutto su localhost)

| Componente           | Host        | Porta  | Protocollo |
|----------------------|-------------|--------|------------|
| SQL Server 2025      | localhost   | 1433   | TCP        |
| Caddy (HTTPS proxy)  | localhost   | 11443  | HTTPS      |
| Ollama               | localhost   | 11434  | HTTP       |

---

## Troubleshooting

**Caddy non si avvia**  
Esegui `caddy validate --config Caddyfile` per verificare la sintassi del file di configurazione.  
Controlla che i path ai certificati siano corretti e che `cert.key` sia leggibile.

**SQL Server rifiuta la connessione HTTPS**  
Il certificato deve essere nel Trusted Root di `LocalMachine` (non solo `CurrentUser`).  
Verifica con `certlm.msc` → *Trusted Root Certification Authorities*.

**Ollama non risponde**  
Controlla che `OLLAMA_HOST` sia impostato come variabile di **sistema** e che il servizio sia stato riavviato dopo la modifica. Verifica con:
```powershell
Get-Service -Name "Ollama"
curl http://localhost:11434/api/tags
```

**`sp_invoke_external_endpoint` non trovata**  
Verifica la versione di SQL Server (richiede almeno la 2022/2025) e che l'opzione `Http Client Enabled` sia stata attivata con `sp_configure`.

**Errore SSL/TLS in SQL Server**  
Assicurati che il campo `subjectAltName` del certificato includa sia `IP:127.0.0.1` che `DNS:localhost`, e che il certificato sia stato importato in `Cert:\LocalMachine\Root`.

---

## Struttura dei file

```
C:\
├── certs\
│   ├── cert.crt       # Certificato self-signed
│   └── cert.key       # Chiave privata
└── Caddy\
    ├── caddy.exe      # Binario Caddy
    └── Caddyfile      # Configurazione Caddy
```