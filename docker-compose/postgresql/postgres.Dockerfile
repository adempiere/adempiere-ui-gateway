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


# Re-apply role passwords from the environment on EVERY start (the stock image only does this
# on the first initdb). custom-entrypoint.sh runs sync-credentials.sh in the background and
# then hands off to the stock postgres entrypoint unchanged.
COPY --chown=postgres:postgres sync-credentials.sh custom-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/sync-credentials.sh /usr/local/bin/custom-entrypoint.sh

# Setting ENTRYPOINT in a derived image resets the inherited CMD, so re-declare it.
ENTRYPOINT ["custom-entrypoint.sh"]
CMD ["postgres"]
