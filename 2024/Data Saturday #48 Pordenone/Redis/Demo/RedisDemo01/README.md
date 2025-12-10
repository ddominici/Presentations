# README

## RedisDemo01

Semplice demo di come utilizzare Redis come cache per un database SQL Server.

### Prerequisiti

1. Istanza SQL Server 2019 o 2022 con installato il database AdventureWorks2019
   1. Si può utilizzare la Developer Edition (gratuita), scaricabile qui:
   https://go.microsoft.com/fwlink/p/?linkid=2215158&clcid=0x409&culture=en-us&country=us
   2. I database di esempio AdventureWorks sono scaricabili qui: 
   https://learn.microsoft.com/it-it/sql/samples/adventureworks-install-configure?view=sql-server-ver16&tabs=ssms
2. Istanza Redis di default (porta 6379)
   1. L'istallazione più semplice è attraverso Docker, utilizzando l'immagine Redis Stack, che include i moduli JSON e Search ed il client grafico RedisInsight: https://hub.docker.com/r/redis/redis-stack

## Utilizzo

Lanciando  il programma RedisDemo01 viene eseguito il metodo GetProducts() della classe AdventureWorksDataService, che tenta di reperire i dati dei prodotti in cache. Se sono presenti, ritorna i dati in cache, altrimenti legge l'elenco dal database e contestualmente li salva in cache per uso successivo.
In caso di errore di lettura della cache per indisponibilità di Redis, la cache viene disabilitata.

Per verificare che il database non venga interrogato quando i dati sono in cache, aprire il Performance Monitor sull'istanza SQL Server ed aggiungere il contatore SQL Server:SQL Statistics\Batch Requests/sec.

La prima esecuzione, con la cache vuota, il contatore sale, ad indicare query sul database, mentre dalla seconda esecuzione i dati vengono reperiti in cache e quindi il database non viene utilizzato.