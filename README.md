# adempiere-ui-gateway
Default Gateway for ADempiere UI

This API Gateway allows define a gateway for ADempiere User Interface, as fisrt services exists:

The main scope for this project is use the gRPC [transcoding](https://cloud.google.com/endpoints/docs/grpc/transcoding)

See [this](https://www.nginx.com/blog/deploying-nginx-plus-as-an-api-gateway-part-1/) article for more info

## Some Advantages

- [API Key Authentication](https://docs.nginx.com/nginx/deployment-guides/single-sign-on/keycloak/)
- [Transformation using Lua](https://clouddocs.f5.com/training/community/nginx/html/class3/module1/module16.html)
- [Transformation using Javascript](https://clouddocs.f5.com/training/community/nginx/html/class3/module1/module16.html)
- [Content Caching](https://docs.nginx.com/nginx/admin-guide/content-cache/content-caching/#:~:text=Overview,the%20same%20content%20every%20time.)

## Run Docker Compose

You can also run it with `docker compose` for develop enviroment. Note that this is a easy way for start the service with PostgreSQL and middleware.

### Requirements

- [Docker Compose v2.16.0 or later](https://docs.docker.com/compose/install/linux/)

```Shell
docker compose version
Docker Compose version v2.16.0
```

## Run it

Just clone it

```Shell
git clone https://github.com/adempiere/adempiere-ui-gateway
cd adempiere-ui-gateway
```

Go to default folder

```Shell
cd docker-compose
```

Run it

```Shell
docker compose up -d
```

Note: For develop option (Only backend services) you can run the follow command:

```Shell
docker compose -f docker-compose-develop.yml up -d
```

After it just open your browser at http://0.0.0.0/

## Some Info

This service just expose the `80` port and you should request using `api.adempiere.io` (for linux just add this domain to `/etc/hosts`).

The main service responding to all request a `nginx`.

```
GNU nano 4.8                                                                                        /etc/hosts                                                                                                   
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
    "deatils": []
}
```
