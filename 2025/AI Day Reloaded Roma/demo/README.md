# AI Day Reloaded

## Istruzioni per l'uso

Questa demo utilizza SQL Server 2025 installato su una virtual machine e Ollama installato direttamente sull'host.
<pre>
Windows 2025, SQL Server 2025 RC2, Caddy (192.168.184.217, porta HTTPS)

MacOS, Ollama (192.168.1.91, porta HTTP)
</pre>

Poiché Ollama comunica usando la porta HTTP e SQL Server richiede che la comunicazione sia in HTTPS, occorre un proxy che traduca le chiamate.
Per farlo ho usato Caddy, ma funziona anche NGINX.

In sostanza, Caddy, installato ed eseguito dalla VM Windows, ascolta sulla porta HTTPS, utilizzando i due certificati autoprodotti, e gira la chiamata ad Ollama usando il protocollo HTTP.

Attenzione nella generazione dei certificati ad utilizzare il nome host corretto o, come nell'esempio, l'indirizzo IP del server dove viene eseguito, altrimenti SQL Server non riesce a validare il certificato.

### Step

1. Installare VM con Windows 2022 o 2025, SQL Server 2025 RC1 e SQL Server Management Studio 21
2. Variare la configurazione di Caddy, generando i certificati per la propria macchina virtuale e modificando il caddyfile (indirizzi ip o nome host) 
   Per generare i certificati occorre eseguire openssl
3. Lanciare run_caddy.bat
4. Lanciare Management Studio ed aprire il file ollama_ai.sql
