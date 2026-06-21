
## Additional Info

The stack exposes port `80`. The main service responding to all requests is `nginx` (service `ui-gateway`).

Set the `HOST_IP` variable in `env_template.env` (or `override.env`) to your server's IP or domain name. Alternatively, add a local alias to `/etc/hosts`:

```
nano /etc/hosts
127.0.0.1       localhost
127.0.1.1       adempiere
<Your-IP-Here>      api.adempiere.io

```

### Request using transcoding

This request uses `nginx` (`ui-gateway`) + Envoy (`grpc-proxy`) + `adempiere-grpc-server` with [gRPC transcoding](https://cloud.google.com/endpoints/docs/grpc/transcoding).

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

---

[Back to README](../README.md)  | [Previous: Troubleshooting](./troubleshooting.md)

