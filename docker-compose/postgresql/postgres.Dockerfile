FROM postgres:13

# Command "wget" will be used for downloading the standard Adempiere Database in initdb.sh, instead of downloading it manually and copying it into the container.
RUN echo 'Update APT package handling utility'
RUN  apt-get update
RUN echo 'Install wget'
RUN apt-get install -y wget
RUN echo 'wget installed'

COPY --chown=1  initdb.sh /docker-entrypoint-initdb.d
COPY --chown=1  after_run /tmp/after_run
RUN chmod +x /docker-entrypoint-initdb.d/initdb.sh
