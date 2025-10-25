# SQL Server 2025 and local AI

## Tecnologie usate

- SQL Server 2025 RC2
- Ollama
- Caddy
- OpenSSL per Windows (64bit)

## SQL Server 2025

Installare SQL Server 2025 (almeno RC1)


## Ollama

Installare Ollama


## Caddy

### Installare OpenSSL

Per generare i certificati self-signed occorre installare OpenSSL.

### Creare i certificati SSL

mkdir -p C:/certs
cd C:/certs

#### Generate new certificate with correct settings

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout C:/certs/cert.key \
  -out C:/certs/cert.crt \
  -subj "/CN=192.168.184.217" \
  -addext "subjectAltName=IP:192.168.184.217"

Verifica il contenuto del certificato

openssl x509 -in C:/certs/cert.crt -text -noout

#### Importa il certificato in Trusted Root Certification Authorities

Import-Certificate -FilePath "C:\certs\cert.crt" -CertStoreLocation Cert:\LocalMachine\Root

#### Create Caddyfile

Attenzione ad utilizzare gli indirizzi IP esatti.
Il certificato deve avere il CN= corretto

Questo file di configurazione consente di dirigere le richieste locali sulla porta 11443 al
server 192.168.1.91, porta 11434 (dove è in ascolto Ollama): 

{
	debug
}

192.168.184.217:11443 {
	tls "c:\certs\cert.crt" "c:\certs\cert.key"
	reverse_proxy 192.168.1.91:11434
	log {	
		output stdout
	}
}

####  

