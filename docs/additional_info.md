
## Additional Info

This service just exposes the port `80`. You should configure to use `api.adempiere.io` (for linux just add this domain to `/etc/hosts`).
Or: change the variable HOST_IP in file env_template.env and .env.

The main service responding to all request a `nginx`.

```
nano /etc/hosts
127.0.0.1       localhost
127.0.1.1       adempiere
<Your-IP-Here>      api.adempiere.io

```

### Request using transcoding

This request use the `nginx` + `envoy` + `adempiere-grpc-server` using [transcoding](https://cloud.google.com/endpoints/docs/grpc/transcoding).

The base URL is `/api/`

**Example Request**

```Shell
curl --location 'http://api.adempiere.io/api/security/services'
```

**Response**
```json
{
    "services": []
}
```

### Request using legacy node server

This request use the `nginx` + `proxy-adempierer-api` using default `http`

The base URL is `/api/`

**Example Request**

```Shell
curl --location 'http://api.adempiere.io/api/user/open-id/services'
```

**Response**
```json
{
    "code": 200,
    "result": []
}
```

Error response format
```json
{
    "code": 1,
    "message": "",
    "details": []
}
```

[Back to README](../README.md)  | [Previous: Troubleshooting](./troubleshooting.md)
