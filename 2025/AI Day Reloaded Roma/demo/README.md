# AI Day Reloaded

## Istruzioni per l'uso

Questa demo utilizza SQL Server 2025 installato su una virtual machine e Ollama installato direttamente sull'host.

|------------- Windows 2025 --------------|       |------ MacOS -----------------|
SQL Server 2025 RC2
(192.168.184.217, porta HTTPS) <--->  Caddy <---> Ollama (192.168.1.91, porta HTTP)


Poiché Ollama comunica usando la porta HTTP e SQL Server richiede che la comunicazione sia in HTTPS, occorre un proxy che traduca le chiamate.
Per farlo ho usato Caddy, ma funziona anche NGINX.

In sostanza, Caddy, installato ed eseguito dalla VM Windows, ascolta sulla porta HTTPS, utilizzando i due certificati autoprodotti, e gira la chiamata ad Ollama usando il protocollo HTTP.

Attenzione nella generazione dei certificati ad utilizzare il nome host corretto o, come nell'esempio, l'indirizzo IP del server dove viene eseguito, altrimenti SQL Server non riesce a validare il certificato.

