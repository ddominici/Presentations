# Entra ID setup for demo 2

Twenty minutes of preparation, once. Do it well before the session and keep the tokens
in a scratch file you can paste from.

## 1. App registration

```bash
az ad app create --display-name "dab-demo-api" \
  --identifier-uris "api://dab-demo" \
  --sign-in-audience AzureADMyOrg
```

Note the **application (client) id** and your **tenant id**. These become
`ENTRA_AUDIENCE` (`api://dab-demo`) and `ENTRA_TENANT_ID` in `.env`.

## 2. App roles

In the portal, under **App roles**, add two roles with allowed member type *Users/Groups*:

| Display name | Value    | Description                          |
|---|---|---|
| Reader       | `reader` | Reads policies without commission    |
| Broker       | `broker` | Reads and updates their own policies |

DAB reads the `roles` claim from the token and matches it against the role names in
`permissions`. The names must match exactly.

## 3. Assign the roles

Assign `reader` to one demo user and `broker` to another, under
**Enterprise applications → dab-demo-api → Users and groups**.

## 4. Map the broker to a database row

Take the broker user's **object id** (`oid` claim) and run
`sql/02-entra-mapping.sql` with it. The item-level policy compares
`@item.broker_oid` with `@claims.oid`.

## 5. Get tokens for the demo

```bash
az account get-access-token --resource "api://dab-demo" --query accessToken -o tsv
```

For two different identities, sign in with `az login` twice in separate shells, or use
a device-code flow per user. Decode at `jwt.ms` and confirm the `roles` and `oid` claims
are present — this is the single most common reason a demo returns 403 on stage.

## 6. Database access for DAB itself

When DAB runs in Azure, prefer a managed identity:

```sql
CREATE USER [dab-demo-identity] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [dab-demo-identity];
ALTER ROLE db_datawriter ADD MEMBER [dab-demo-identity];
GRANT EXECUTE ON SCHEMA::dbo TO [dab-demo-identity];
```

Least privilege matters here: DAB should never connect as `db_owner`. On a laptop,
`Authentication=Active Directory Default` uses your `az login` context instead.

## Optional: On-Behalf-Of (2.0)

To let Azure SQL authenticate as the *end user* rather than as DAB:

```bash
export DAB_OBO_CLIENT_ID=<app registration client id>
export DAB_OBO_TENANT_ID=<tenant id>
export DAB_OBO_CLIENT_SECRET=<client secret>

dab configure --data-source.user-delegated-auth.enabled true
dab configure --data-source.user-delegated-auth.provider EntraId
dab configure --data-source.user-delegated-auth.database-audience "https://database.windows.net"
dab configure --runtime.cache.enabled false        # required: caching must be off with OBO
```

The app registration needs permission to request tokens for the database, and the SQL
instance must accept Entra tokens. With OBO on, DAB keeps a separate connection pool per
user, so one user's token is never reused for another's request — which is exactly why
caching has to go.
