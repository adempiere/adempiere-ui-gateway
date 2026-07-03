ARG POSTGRES_IMAGE
FROM ${POSTGRES_IMAGE}

ENV HOME_PATH_ON_CONTAINERS=/home/adempiere
ENV POSTGRES_DB_BACKUP_PATH_ON_CONTAINER=${HOME_PATH_ON_CONTAINERS}/postgres_backups


RUN mkdir -p $POSTGRES_DB_BACKUP_PATH_ON_CONTAINER && \
	chown -R postgres:postgres $POSTGRES_DB_BACKUP_PATH_ON_CONTAINER


# Command "wget" will be used for downloading the standard Adempiere Database in
# initdb.sh, instead of downloading it manually and copying it into the container.
RUN echo 'Update APT package handling utility' && \
	apt-get update && \
	echo 'Install wget' && \
	apt-get install -y \
		ca-certificates \
		wget && \
	echo 'wget installed'



COPY --chown=postgres:postgres initdb.sh /docker-entrypoint-initdb.d/
COPY --chown=postgres:postgres after_run/*.sql /tmp/after_run/

RUN chmod +x /docker-entrypoint-initdb.d/initdb.sh
