## Display Services
### Main Services
- Project site: open browser and type in the following urls
  - [http://localhost:80](http://localhost:80)
  - [http://localhost](http://localhost)
  - http://0.0.0.0/
  - httpp://api.adempiere.io (it must be configured to which host it points)
- Or you can use IP as defined in configuration file (env_template.env or .env) in variables HOST_URL, ADEMPIERE_SITE_EXTERNAL_PORT
  From here, the user can navigate via buttons to ZK UI, Vue UI or Envoy browser.
- Open separately Adempiere ZK: open browser and type in the following url [${HOST_URL}/webui](${HOST_URL}/webui)
- HOST_URL can be also defined in configuration file (env_template.env or .env) to be accessed via port e.g. [http://localhost:8888](http://localhost:8888)
  Or use IP as defined in configuration file (env_template.env or .env) in variables HOST_URL, ADEMPIERE_ZK_EXTERNAL_PORT
  (`TO BE VERIFIED YET`)
- Open separately Adempiere Vue: open browser and type in the following url
  - [${HOST_URL}/vue](${HOST_URL}/vue)
  HOST_URL as defined in configuration file (env_template.env or .env)
- Open separately DKron Envoy Monitor:  httpp://api.adempiere.io:8899

### Other services
**OpenSearch Dashboard**
![OpenSearch Dashboard](./services-opensearch-dashboard.png)

**Kafdrop Kafka Queue Monitor/Administrator**
![Kaffdrop Kafka Queue Monitor](./services-kafdrop.png)

**DKron Envoy Process Monitor**
![DKron Envoy Process Monitor](./services-dkron.png)

**MinIO Object Monitor**
![MinIO Objet Monitor](./services-minio.png)


[Back to README](../README.md) | [Previous: Installation](./installation.md) | [Next: Security](./security.md)
