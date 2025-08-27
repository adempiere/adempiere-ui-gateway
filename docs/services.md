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
![Selection_522](https://github.com/adempiere/adempiere-ui-gateway/assets/1789408/abe548f6-0ed1-4b91-b70d-d1d0729d9600)

**Kafdrop Kafka Queue Monitor/Administrator**
![Selection_523](https://github.com/adempiere/adempiere-ui-gateway/assets/1789408/7c15df8c-6cd9-4eea-92ac-c03bfd3d36b9)

**DKron Envoy Process Monitor**
![26-DKron-Browser png](https://github.com/user-attachments/assets/01bf6316-89fd-4c4b-b309-49f08e20263b)

**MinIO Object Monitor**
![Selection_604](https://github.com/user-attachments/assets/556fbc3e-2e79-45ec-ad16-5dc55cdd79e7)


[Back to README](../README.md) | [Previous: Installation](./installation.md) | [Next: Security](./security.md)
