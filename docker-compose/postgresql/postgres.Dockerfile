FROM postgres:14.5


# Command "wget" will be used for downloading the standard Adempiere Database in
# initdb.sh, instead of downloading it manually and copying it into the container.
RUN echo 'Update APT package handling utility' && \
	apt-get update && \
	echo 'Install wget' && \
	apt-get install -y \
		ca-certificates \
		wget && \
	echo 'wget installed'


COPY --chown=1 initdb.sh /docker-entrypoint-initdb.d
COPY --chown=1 after_run/*.sql /tmp/after_run/


RUN chmod +x /docker-entrypoint-initdb.d/initdb.sh
