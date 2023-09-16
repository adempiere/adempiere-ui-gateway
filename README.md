# adempiere-ui-gateway
Default Gateway for ADempiere UI

This API Gateway allows define a gateway for ADempiere User Interface, as fisrt services exists:

The main scope for this project is use the gRPC [transcoding](https://cloud.google.com/endpoints/docs/grpc/transcoding)

See [this](https://www.nginx.com/blog/deploying-nginx-plus-as-an-api-gateway-part-1/) article for more info

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

```Shell
docker compose up
```

## Some Info

This service just expose the `80` port and you should request using `api.adempiere.io` (for linux just add this domain to `/etc/hosts`).

The main service responding to all request a `nginx`.

```
GNU nano 4.8                                                                                        /etc/hosts                                                                                                   
127.0.0.1       localhost
127.0.1.1       adempiere
<Your-IP-Here>      api.adempiere.io

```

**Example Request**

```Shell
curl --location 'http://api.adempiere.io/v1/open-id/services'
```

**Response**
```
{
    "services": []
}
```