#!/bin/bash

# Script to -if necessary- 
#   1.- create on host persistent directories and 
#   2.- start the docker compose services

# 1.- CREATE ON HOST PERSISTENT DIRECTORIES
#     Directory needed for storing persistently Postgres database on host.
#     Directory will be created on host only if inexistent.
#     Docker Compose will create this directory via volume definition.
DBDIR=postgresql/postgres_database
if [ ! -d "$DBDIR" ]; then
    echo "Directory \"$DBDIR\" does not exist. It must be created."
    echo "Create directory \"$DBDIR\""
	mkdir -p $DBDIR
else
    echo "Directory \"$DBDIR\" exists already: no need to create it"
fi

# Backup directory for storing the Postgres backup file on host.
# Directory will be created on host only if inexistent.
# Docker Compose will create this directory via volume definition.
# The name of the backup file must be "seed.backup" as defined in Docker Compose.
BACKUPDIR=postgresql/postgres_backups
if [ ! -d "$BACKUPDIR" ]; then
    echo "Directory \"$BACKUPDIR\" does not exist. It must be created."
    echo "Create directory \"$BACKUPDIR\""
	mkdir -p $BACKUPDIR
    chmod 777 $BACKUPDIR
else
    echo "Directory \"$BACKUPDIR\" exists already: no need to create it"
fi

# Directory needed for storing persistently ZK container files on host.
# Directory will be created only if inexistent.
# Docker Compose will create this directory via volume definition.
PERSISTENTDIR=postgresql/persistent_files
if [ ! -d "$PERSISTENTDIR" ]; then
    echo "Directory \"$PERSISTENTDIR\" does not exist. It must be created."
    echo "Create directory \"$PERSISTENTDIR\""
	mkdir -p $PERSISTENTDIR
    chmod 777 $PERSISTENTDIR
else
    echo "Directory \"$PERSISTENTDIR\" exists already: no need to create it"
fi

# 2.- START THE DOCKER COMPOSE SERVICES

# 2a.- Variables for services
#      The number defines the order the services wil be defined in the docker compose file
#      When the order changes, so also the sequence the services will be defined in the docker compose file
POSTGRESQL_SERVICE=0
S3_STORAGE=1
S3_CLIENT=2
S3_GATEWAY_RS=3
ADEMPIERE_SITE=4
ADEMPIERE_ZK=5
ADEMPIERE_PROCESSOR=6
DKRON_SCHEDULER=7
ADEMPIERE_GRPC_SERVER=8
GRPC_PROXY=9
VUE_UI=10
ZOOKEEPER=11
KAFKA=12
OPENSEARCH_NODE=13
OPENSEARCH_SETUP=14
OPENSEARCH_GATEWAY_RS=15
UI_GATEWAY=16
KEYCLOAK=17
NO_SERVICE_IMPLEMENTED=NO_SERVICE_IMPLEMENTED

# 2b.- All services enumerated in the order the arrays are filled.
#      The order must match the number they are defined as variables above.
#      (there is no way assotiated arrays can be ordered).
#      It will be used when looping through the selected services array.
declare -a SERVICES_ordered_array
SERVICES_ordered_array=(POSTGRESQL_SERVICE S3_STORAGE S3_CLIENT S3_GATEWAY_RS ADEMPIERE_SITE ADEMPIERE_ZK ADEMPIERE_PROCESSOR DKRON_SCHEDULER ADEMPIERE_GRPC_SERVER GRPC_PROXY VUE_UI ZOOKEEPER KAFKA OPENSEARCH_NODE OPENSEARCH_SETUP OPENSEARCH_GATEWAY_RS UI_GATEWAY KEYCLOAK)


# 2c.- Define arrays for service cases
#      All arrays MUST comply to the same order (indixed must be the same)
#      The arrays define which services will be implemented for each one
#      Every service is contained in a file.
#      This way any service combination can be achieved and a specific service is defined only once.

# Services for AUTH
declare -a AUTH_array
AUTH_array[$POSTGRESQL_SERVICE]="01b-postgres_service_without_ports.yml"
AUTH_array[$S3_STORAGE]="02a-s3_storage_service.yml"
AUTH_array[$S3_CLIENT]="03a-s3_client_service.yml"
AUTH_array[$S3_GATEWAY_RS]="04b-s3_gateway_rs_service_standard.yml"
AUTH_array[$ADEMPIERE_SITE]="05a-adempiere_site_service.yml"
AUTH_array[$ADEMPIERE_ZK]="06a-adempiere_zk_service.yml"
AUTH_array[$ADEMPIERE_PROCESSOR]="07a-adempiere_processor_service.yml"
AUTH_array[$DKRON_SCHEDULER]="08a-dkron_scheduler_service.yml"
AUTH_array[$ADEMPIERE_GRPC_SERVER]="09a-adempiere_grpc_server_service.yml"
AUTH_array[$GRPC_PROXY]="10c-grpc_proxy_service_standard.yml"
AUTH_array[$VUE_UI]="11a-vue_ui_service.yml"
AUTH_array[$ZOOKEEPER]="12a-zookeeper_service.yml"
AUTH_array[$KAFKA]="13a-kafka_service.yml"
AUTH_array[$OPENSEARCH_NODE]="14b-opensearch_node_service_without_port.yml"
AUTH_array[$OPENSEARCH_SETUP]="15a-opensearch_setup_service.yml"
AUTH_array[$OPENSEARCH_GATEWAY_RS]="16a-opensearch_gateway_rs_service_standard.yml"
AUTH_array[$UI_GATEWAY]="17a-ui_gateway_service_auth.yml"
AUTH_array[$KEYCLOAK]="18a-keycloak_service.yml"

# Services for CACHE
declare -a CACHE_array
CACHE_array[$POSTGRESQL_SERVICE]="01b-postgres_service_without_ports.yml"
CACHE_array[$S3_STORAGE]="$NO_SERVICE_IMPLEMENTED"
CACHE_array[$S3_CLIENT]="$NO_SERVICE_IMPLEMENTED"
CACHE_array[$S3_GATEWAY_RS]="$NO_SERVICE_IMPLEMENTED"
CACHE_array[$ADEMPIERE_SITE]="$NO_SERVICE_IMPLEMENTED"
CACHE_array[$ADEMPIERE_ZK]="$NO_SERVICE_IMPLEMENTED"
CACHE_array[$ADEMPIERE_PROCESSOR]="$NO_SERVICE_IMPLEMENTED"
CACHE_array[$DKRON_SCHEDULER]="$NO_SERVICE_IMPLEMENTED"
CACHE_array[$ADEMPIERE_GRPC_SERVER]="09a-adempiere_grpc_server_service.yml"
CACHE_array[$GRPC_PROXY]="10d-grpc_proxy_service_vue.yml"
CACHE_array[$VUE_UI]="11a-vue_ui_service.yml"
CACHE_array[$ZOOKEEPER]="12a-zookeeper_service.yml"
CACHE_array[$KAFKA]="13a-kafka_service.yml"
CACHE_array[$OPENSEARCH_NODE]="14a-opensearch_node_service_with_port.yml"
CACHE_array[$OPENSEARCH_SETUP]="15a-opensearch_setup_service.yml"
CACHE_array[$OPENSEARCH_GATEWAY_RS]="16a-opensearch_gateway_rs_service_standard.yml"
CACHE_array[$UI_GATEWAY]="17b-ui_gateway_service_cache.yml"
CACHE_array[$KEYCLOAK]="$NO_SERVICE_IMPLEMENTED"

# Services for DEVELOP
declare -a DEVELOP_array
DEVELOP_array[$POSTGRESQL_SERVICE]="01a-postgres_service_with_ports.yml"
DEVELOP_array[$S3_STORAGE]="02a-s3_storage_service.yml"
DEVELOP_array[$S3_CLIENT]="03a-s3_client_service.yml"
DEVELOP_array[$S3_GATEWAY_RS]="04a-s3_gateway_rs_service_develop.yml"
DEVELOP_array[$ADEMPIERE_SITE]="05a-adempiere_site_service.yml"
DEVELOP_array[$ADEMPIERE_ZK]="06a-adempiere_zk_service.yml"
DEVELOP_array[$ADEMPIERE_PROCESSOR]="07a-adempiere_processor_service.yml"
DEVELOP_array[$DKRON_SCHEDULER]="08a-dkron_scheduler_service.yml"
DEVELOP_array[$ADEMPIERE_GRPC_SERVER]="09a-adempiere_grpc_server_service.yml"
DEVELOP_array[$GRPC_PROXY]="10b-grpc_proxy_service_develop.yml"
DEVELOP_array[$VUE_UI]="11a-vue_ui_service.yml"
DEVELOP_array[$ZOOKEEPER]="12a-zookeeper_service.yml"
DEVELOP_array[$KAFKA]="13a-kafka_service.yml"
DEVELOP_array[$OPENSEARCH_NODE]="14a-opensearch_node_service_with_port.yml"
DEVELOP_array[$OPENSEARCH_SETUP]="15a-opensearch_setup_service.yml"
DEVELOP_array[$OPENSEARCH_GATEWAY_RS]="16c-opensearch_gateway_rs_service_develop.yml"
DEVELOP_array[$UI_GATEWAY]="17c-ui_gateway_service_develop.yml"
DEVELOP_array[$KEYCLOAK]="18a-keycloak_service.yml"

# Services for STANDARD
declare -a STANDARD_array
STANDARD_array[$POSTGRESQL_SERVICE]="01b-postgres_service_without_ports.yml"
STANDARD_array[$S3_STORAGE]="02a-s3_storage_service.yml"
STANDARD_array[$S3_CLIENT]="03a-s3_client_service.yml"
STANDARD_array[$S3_GATEWAY_RS]="04b-s3_gateway_rs_service_standard.yml"
STANDARD_array[$ADEMPIERE_SITE]="05a-adempiere_site_service.yml"
STANDARD_array[$ADEMPIERE_ZK]="06a-adempiere_zk_service.yml"
STANDARD_array[$ADEMPIERE_PROCESSOR]="07a-adempiere_processor_service.yml"
STANDARD_array[$DKRON_SCHEDULER]="08a-dkron_scheduler_service.yml"
STANDARD_array[$ADEMPIERE_GRPC_SERVER]="09a-adempiere_grpc_server_service.yml"
STANDARD_array[$GRPC_PROXY]="10c-grpc_proxy_service_standard.yml"
STANDARD_array[$VUE_UI]="11a-vue_ui_service.yml"
STANDARD_array[$ZOOKEEPER]="12a-zookeeper_service.yml"
STANDARD_array[$KAFKA]="13a-kafka_service.yml"
STANDARD_array[$OPENSEARCH_NODE]="14b-opensearch_node_service_without_port.yml"
STANDARD_array[$OPENSEARCH_SETUP]="15a-opensearch_setup_service.yml"
STANDARD_array[$OPENSEARCH_GATEWAY_RS]="16a-opensearch_gateway_rs_service_standard.yml"
STANDARD_array[$UI_GATEWAY]="17d-ui_gateway_service_standard.yml"
STANDARD_array[$KEYCLOAK]="$NO_SERVICE_IMPLEMENTED"

# Services for STORAGE
declare -a STORAGE_array
STORAGE_array[$POSTGRESQL_SERVICE]="01b-postgres_service_without_ports.yml"
STORAGE_array[$S3_STORAGE]="02a-s3_storage_service.yml"
STORAGE_array[$S3_CLIENT]="03a-s3_client_service.yml"
STORAGE_array[$S3_GATEWAY_RS]="04c-s3_gateway_rs_service_standard.yml"
STORAGE_array[$ADEMPIERE_SITE]="$NO_SERVICE_IMPLEMENTED"
STORAGE_array[$ADEMPIERE_ZK]="$NO_SERVICE_IMPLEMENTED"
STORAGE_array[$ADEMPIERE_PROCESSOR]="$NO_SERVICE_IMPLEMENTED"
STORAGE_array[$DKRON_SCHEDULER]="$NO_SERVICE_IMPLEMENTED"
STORAGE_array[$ADEMPIERE_GRPC_SERVER]="09a-adempiere_grpc_server_service.yml"
STORAGE_array[$GRPC_PROXY]="10d-grpc_proxy_service_vue.yml"
STORAGE_array[$VUE_UI]="11a-vue_ui_service.yml"
STORAGE_array[$ZOOKEEPER]="$NO_SERVICE_IMPLEMENTED"
STORAGE_array[$KAFKA]="$NO_SERVICE_IMPLEMENTED"
STORAGE_array[$OPENSEARCH_NODE]="$NO_SERVICE_IMPLEMENTED"
STORAGE_array[$OPENSEARCH_SETUP]="$NO_SERVICE_IMPLEMENTED"
STORAGE_array[$OPENSEARCH_GATEWAY_RS]="$NO_SERVICE_IMPLEMENTED"
STORAGE_array[$UI_GATEWAY]="17e-ui_gateway_service_storage.yml"
STORAGE_array[$KEYCLOAK]="$NO_SERVICE_IMPLEMENTED"

# Services for VUE
declare -a VUE_array
VUE_array[$POSTGRESQL_SERVICE]="01b-postgres_service_without_ports.yml"
VUE_array[$S3_STORAGE]="$NO_SERVICE_IMPLEMENTED"
VUE_array[$S3_CLIENT]="$NO_SERVICE_IMPLEMENTED"
VUE_array[$S3_GATEWAY_RS]="$NO_SERVICE_IMPLEMENTED"
VUE_array[$ADEMPIERE_SITE]="$NO_SERVICE_IMPLEMENTED"
VUE_array[$ADEMPIERE_ZK]="$NO_SERVICE_IMPLEMENTED"
VUE_array[$ADEMPIERE_PROCESSOR]="$NO_SERVICE_IMPLEMENTED"
VUE_array[$DKRON_SCHEDULER]="$NO_SERVICE_IMPLEMENTED"
VUE_array[$ADEMPIERE_GRPC_SERVER]="09a-adempiere_grpc_server_service.yml"
VUE_array[$GRPC_PROXY]="10d-grpc_proxy_service_vue.yml"
VUE_array[$VUE_UI]="11a-vue_ui_service.yml"
VUE_array[$ZOOKEEPER]="$NO_SERVICE_IMPLEMENTED"
VUE_array[$KAFKA]="$NO_SERVICE_IMPLEMENTED"
VUE_array[$OPENSEARCH_NODE]="$NO_SERVICE_IMPLEMENTED"
VUE_array[$OPENSEARCH_SETUP]="$NO_SERVICE_IMPLEMENTED"
VUE_array[$OPENSEARCH_GATEWAY_RS]="$NO_SERVICE_IMPLEMENTED"
VUE_array[$UI_GATEWAY]="17f-ui_gateway_service_vue.yml"
VUE_array[$KEYCLOAK]="$NO_SERVICE_IMPLEMENTED"

# All arrays that contain services have been defined. Now proceed to the creation of the docker compose file.

# 3.- Find out which Docker Compose service combination will be executed.
#     The script must be called with the flag "-d" + one of the following parameters [auth, cache, develop, storage, vue, default]
#     Additionally, it can be called with the flag "-l" (legacy). This means, it will use the old docker-compose.yml files insrtead of the new services files.
#     The defaults are "no legacy" (= -l non-existent) and -d = "default" (=standard services file)
#     Examples:
#       ./start-all.sh -d vue
#           The services combination for Vue will be assembled to docker-compose.yml, and docker compose will be executed with this file.
#       ./start-all.sh -d vue -l
#           The file docker-compose-vue.yml will be copied to docker-compose.yml, and docker compose will be executed with this file.
#       ./start-all.sh -d cache
#           The services combination for Cache will be assembled to docker-compose.yml, and docker compose will be executed with this file.
#       ./start-all.sh -d cache -l
#           The file docker-compose-cache.yml will be copied to docker-compose.yml, and docker compose will be executed with this file.
#       ./start-all.sh
#           If script is called without or with a flag, 'default' will be taken.
#           The services combination for Standard will be assembled to docker-compose.yml, and docker compose will be executed with this file.

legacy_behavior=0              # don't do legacy behavior by default
docker_compose_option=default  # Default: the "standard" file.

# Catch when there is only one parameter, and it is = "-l"
if [ ${#} -eq 1 ] && [ "${1}" == "-l" ]
then
    legacy_behavior=1
else
    # There is more than one parameter; the order is irrelevant.
    while getopts ':d:l:' flag
    do
        case "${flag}" in
            d) # ./start-all.sh -d [auth, cache, develop, storage, vue, default] -l
               # ${1}="-d" ${2}=(string after "-d") ${3}="-l" ${OPTARG}=(string after "-d")
               docker_compose_option=${OPTARG}
               if [ "${3}" = "-l" ];then legacy_behavior=1;fi;;
            l) # ./start-all.sh -l -d [auth, cache, develop, storage, vue, default]
               # ${1}="-l" ${2}="-l" ${3}=(string after "-l") ${OPTARG}="-d"
               legacy_behavior=1;
               if [ "${OPTARG}"="-d" ];then docker_compose_option=${3};fi;;
            # *) echo "By getopts loop this is called at the end. That's why it shouldn't be programmed";;
        esac
    done
fi

echo "Script called with mode parameter: \"$docker_compose_option\" and legacy parameter: $legacy_behavior";
    
# 4.- Set the services array that will be used depending on the input flag "-d"
DOCKER_COMPOSE_FILE=docker-compose.yml

LEGACY_AUTH_DOCKER_COMPOSE_FILE=docker-compose-auth.yml
LEGACY_CACHE_DOCKER_COMPOSE_FILE=docker-compose-cache.yml
LEGACY_DEVELOP_DOCKER_COMPOSE_FILE=docker-compose-develop.yml
LEGACY_STANDARD_DOCKER_COMPOSE_FILE=docker-compose-standard.yml
LEGACY_STORAGE_DOCKER_COMPOSE_FILE=docker-compose-storage.yml
LEGACY_VUE_DOCKER_COMPOSE_FILE=docker-compose-vue.yml

case "${docker_compose_option}" in
    auth)    MODE_SERVICES=AUTH
             if [ $legacy_behavior -eq 1 ]
             then
               cp $LEGACY_AUTH_DOCKER_COMPOSE_FILE $DOCKER_COMPOSE_FILE && echo "File \"$LEGACY_AUTH_DOCKER_COMPOSE_FILE\" copied to  \"$DOCKER_COMPOSE_FILE\""; 
             else
               services_array=(${AUTH_array[*]})
             fi;;

    cache)   MODE_SERVICES=CACHE
             if [ $legacy_behavior -eq 1 ]
             then
               cp $LEGACY_CACHE_DOCKER_COMPOSE_FILE $DOCKER_COMPOSE_FILE && echo "File \"$LEGACY_CACHE_DOCKER_COMPOSE_FILE\" copied to \"$DOCKER_COMPOSE_FILE\""; 
             else
               services_array=(${CACHE_array[*]})
             fi;;

    develop) MODE_SERVICES=DEVELOP
             if [ $legacy_behavior -eq 1 ]
             then
               cp $LEGACY_DEVELOP_DOCKER_COMPOSE_FILE $DOCKER_COMPOSE_FILE && echo "File \"$LEGACY_DEVELOP_DOCKER_COMPOSE_FILE\" copied to  \"$DOCKER_COMPOSE_FILE\""; 
             else
               services_array=(${DEVELOP_array[*]})
             fi;;

    storage) MODE_SERVICES=STORAGE
             if [ $legacy_behavior -eq 1 ]
             then
               cp $LEGACY_STORAGE_DOCKER_COMPOSE_FILE $DOCKER_COMPOSE_FILE && echo "File \"$LEGACY_STORAGE_DOCKER_COMPOSE_FILE\" copied to  \"$DOCKER_COMPOSE_FILE\""; 
             else
               services_array=(${STORAGE_array[*]})
             fi;;

    vue)     MODE_SERVICES=VUE
             if [ $legacy_behavior -eq 1 ]
             then
               cp $LEGACY_VUE_DOCKER_COMPOSE_FILE $DOCKER_COMPOSE_FILE && echo "File \"$LEGACY_VUE_DOCKER_COMPOSE_FILE\" copied to \"$DOCKER_COMPOSE_FILE\""; 
             else
               services_array=(${VUE_array[*]})
             fi;;

    default|*) MODE_SERVICES=STANDARD     # STANDARD is the default
             if [ $legacy_behavior -eq 1 ]
             then
               cp $LEGACY_STANDARD_DOCKER_COMPOSE_FILE $DOCKER_COMPOSE_FILE && echo "File \"$LEGACY_STANDARD_DOCKER_COMPOSE_FILE\" copied to  \"$DOCKER_COMPOSE_FILE\""; 
             else
               services_array=(${STANDARD_array[*]})
             fi;;
esac

# 5.- Reset the Docker Compose file and
#     Fill the  Docker Compose file with the contents of the files specified in the array
#     Header and footer are used for anything but services.
# This is valid only if NOT in legacy mode.
# When in legacy mode, the docker compose file was already copied and no creation of a docker compose file is needed.
if [ $legacy_behavior -eq 0 ]
then
    DOCKER_COMPOSE_HEADER_FILE=90-docker_compose_HEADER.yml
    DOCKER_COMPOSE_FOOTER_FILE=91-docker_compose_FOOTER.yml

    echo Fill the  Docker Compose file with services for $MODE_SERVICES
    > $DOCKER_COMPOSE_FILE

    cat $DOCKER_COMPOSE_HEADER_FILE >> $DOCKER_COMPOSE_FILE
    echo "# Services definition for $MODE_SERVICES" >> $DOCKER_COMPOSE_FILE
    for service_index in ${!services_array[@]}  # Loop on indexes ($service_index is the index)
    do
        if [ ${services_array[$service_index]} = "$NO_SERVICE_IMPLEMENTED" ]
        then
        echo $'\n' "# Service $(($service_index+1)) (${SERVICES_ordered_array[$service_index]}) not implemented" | tee -a $DOCKER_COMPOSE_FILE
        else
        cat ${services_array[$service_index]} >> $DOCKER_COMPOSE_FILE
        echo Contents of ${services_array[$service_index]} copied to  $DOCKER_COMPOSE_FILE
        fi
    done
    cat $DOCKER_COMPOSE_FOOTER_FILE >> $DOCKER_COMPOSE_FILE
fi

# 6.- Execute docker compose
echo "Docker Compose will be executed with file: \"$DOCKER_COMPOSE_FILE\""
cp env_template.env .env
#docker compose -f $DOCKER_COMPOSE_FILE --dry-run up -d
docker compose -f $DOCKER_COMPOSE_FILE up -d

echo "Docker Compose started"
