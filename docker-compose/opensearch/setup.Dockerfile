FROM debian:bookworm-20250630-slim

ENV \
	OPENSEARCH_HOST="http://opensearch-node:9200"


RUN apt-get update && \
	apt-get install -y \
		tzdata \
		bash \
		curl && \
	rm -rf /var/lib/apt/lists/* \
	rm -rf /tmp/* && \
	echo "Set Timezone..." && \
	echo $TZ > /etc/timezone


COPY --chown=1 setup_opensearch.sh /opt/apps/setup_opensearch.sh


RUN addgroup adempiere && \
	adduser --disabled-password --gecos "" --ingroup adempiere --no-create-home adempiere && \
	chmod +x /opt/apps/setup_opensearch.sh


USER adempiere


ENTRYPOINT ["sh" , "/opt/apps/setup_opensearch.sh"]
