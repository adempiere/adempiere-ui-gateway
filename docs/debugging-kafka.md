# Kafka Debugging and Testing Guide

This guide covers how to test and debug Kafka from the server using CLI tools inside the Docker container.  
No firewall ports need to be opened — all CLI access runs on the server via SSH.

For the Kafdrop browser UI (topic inspection, message browsing), see [Remote Access via SSH Tunnel](./remote-access.md#kafdrop--kafka-topic-browser-port-19000).

---

## How access works

All Kafka CLI tools run **inside the `kafka` container** via `docker exec`.  
The bootstrap server address is always `kafka:9092` — the internal Docker network name.   

The external Kafka port (typically 29092) is used only by clients that connect from outside (e.g. via WireGuard VPN). It is not used for CLI testing.

```
Local machine  →  SSH  →  Server  →  docker exec  →  kafka container  →  kafka:9092
```

**Prerequisite:** SSH access to the server.  
All commands below are run on the server after connecting via SSH.

### SSH key setup (one-time)

SSH key authentication uses a key pair:  
- a **private key** (stays on your local machine) and  
- a **public key** (installed on the server).

**Generate the key pair** on your local machine:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/<key-name>
```

This creates two files:  
- `~/.ssh/<key-name>`       (private) and  
- `~/.ssh/<key-name>.pub`   (public).

**Copy the public key to the server:**

```bash
ssh-copy-id -i ~/.ssh/<key-name>.pub -p <ssh-port> <user>@<server-ip>
```

The public key is appended to `~/.ssh/authorized_keys` on the server.  
The private key never leaves your local machine.

**Connect using the private key** (`-i` points to it):

```bash
ssh -i <path-to-ssh-key> -p <ssh-port> <user>@<server-ip>
```

Then change to the docker-compose directory:

```bash
cd /opt/development/adempiere-ui-gateway/docker-compose
```

> **Note:** All `docker compose` commands on this server require `sudo`.

---

## Topic management

### List all topics

```bash
sudo docker exec adempiere-ui-gateway.kafka \
  kafka-topics --bootstrap-server kafka:9092 --list
```

### Create a topic

```bash
sudo docker exec adempiere-ui-gateway.kafka \
  kafka-topics --bootstrap-server kafka:9092 \
  --create --topic <topic-name> \
  --partitions 1 --replication-factor 1
```

### Describe a topic (partitions, offsets, replication)

```bash
sudo docker exec adempiere-ui-gateway.kafka \
  kafka-topics --bootstrap-server kafka:9092 \
  --describe --topic <topic-name>
```

### Delete a topic

```bash
sudo docker exec adempiere-ui-gateway.kafka \
  kafka-topics --bootstrap-server kafka:9092 \
  --delete --topic <topic-name>
```

---

## Producing messages

### Produce a single message interactively

This command opens a prompt. Each line you type becomes one Kafka message. Press `Ctrl+C` to exit.

```bash
sudo docker exec -it adempiere-ui-gateway.kafka \
  kafka-console-producer --bootstrap-server kafka:9092 \
  --topic <topic-name>
```

Type the message and press Enter:

```
hello-from-server
```

### Produce a message with a specific key

```bash
sudo docker exec -it adempiere-ui-gateway.kafka \
  kafka-console-producer --bootstrap-server kafka:9092 \
  --topic <topic-name> \
  --property "parse.key=true" \
  --property "key.separator=:"
```

Type `key:value` and press Enter:

```
print_queue_document:{"port_name":"test-printer","document":"..."}
```

---

## Consuming messages

### Consume all messages from the beginning (one-shot)

```bash
sudo docker exec adempiere-ui-gateway.kafka \
  kafka-console-consumer --bootstrap-server kafka:9092 \
  --topic <topic-name> \
  --from-beginning \
  --max-messages 10
```

### Consume in real time (follow mode)

Press `Ctrl+C` to stop.

```bash
sudo docker exec -it adempiere-ui-gateway.kafka \
  kafka-console-consumer --bootstrap-server kafka:9092 \
  --topic <topic-name> \
  --from-beginning
```

### Consume and display keys

```bash
sudo docker exec -it adempiere-ui-gateway.kafka \
  kafka-console-consumer --bootstrap-server kafka:9092 \
  --topic <topic-name> \
  --from-beginning \
  --property print.key=true \
  --property key.separator=" → "
```

---

## Consumer group inspection

This is the primary way to verify whether a client (e.g. the Windows ERP App Service) has consumed messages.

### List all consumer groups

```bash
sudo docker exec adempiere-ui-gateway.kafka \
  kafka-consumer-groups --bootstrap-server kafka:9092 --list
```

### Describe a consumer group

```bash
sudo docker exec adempiere-ui-gateway.kafka \
  kafka-consumer-groups --bootstrap-server kafka:9092 \
  --describe --group <group-id>
```

Example output:

```
GROUP               TOPIC                    PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG  CONSUMER-ID              HOST
<group-id>          <topic-name>             0          5               5               0    rdkafka-...              /10.0.0.2
```

| Column | Meaning |
|--------|---------|
| `CURRENT-OFFSET` | Last offset the consumer confirmed as processed |
| `LOG-END-OFFSET` | Total number of messages in the partition |
| `LAG` | Messages not yet consumed (`LOG-END-OFFSET - CURRENT-OFFSET`) |
| `HOST` | IP of the consuming client |

**LAG = 0** means the consumer has read all messages.  
**LAG > 0** means the consumer is behind (or not connected).

### Describe all consumer groups at once

```bash
sudo docker exec adempiere-ui-gateway.kafka \
  kafka-consumer-groups --bootstrap-server kafka:9092 \
  --describe --all-groups
```

---

## End-to-end test procedure

Use this to verify that Kafka is fully functional independently of any application.

**Step 1 — Create a test topic:**

```bash
sudo docker exec adempiere-ui-gateway.kafka \
  kafka-topics --bootstrap-server kafka:9092 \
  --create --topic kafka-test --partitions 1 --replication-factor 1
```

**Step 2 — Open a consumer in Terminal 1 (keep this running):**

```bash
sudo docker exec -it adempiere-ui-gateway.kafka \
  kafka-console-consumer --bootstrap-server kafka:9092 \
  --topic kafka-test --from-beginning
```

**Step 3 — Produce a message in Terminal 2:**

```bash
sudo docker exec -it adempiere-ui-gateway.kafka \
  kafka-console-producer --bootstrap-server kafka:9092 \
  --topic kafka-test
```

Type `hello-kafka-test` and press Enter.

**Step 4 — Verify:** The message `hello-kafka-test` should appear immediately in Terminal 1.

**Step 5 — Clean up:**

```bash
sudo docker exec adempiere-ui-gateway.kafka \
  kafka-topics --bootstrap-server kafka:9092 \
  --delete --topic kafka-test
```

---

## Verifying whether the Windows ERP App Service consumed a message

This procedure confirms end-to-end delivery from the server to any Kafka consumer.

**Step 1 — Note the current offset** before stopping the service:

```bash
sudo docker exec adempiere-ui-gateway.kafka \
  kafka-consumer-groups --bootstrap-server kafka:9092 \
  --describe --group <topic-name>
```

**Step 2 — Stop the Windows ERP App Service** (so no consumer is connected).

**Step 3 — Produce a test message** (or trigger a POS invoice in ADempiere).

**Step 4 — Confirm the message is waiting** (LAG should be 1):

```bash
sudo docker exec adempiere-ui-gateway.kafka \
  kafka-consumer-groups --bootstrap-server kafka:9092 \
  --describe --group <topic-name>
```

**Step 5 — Start the Windows ERP App Service.**

**Step 6 — Confirm the message was consumed** (LAG should return to 0):

```bash
sudo docker exec adempiere-ui-gateway.kafka \
  kafka-consumer-groups --bootstrap-server kafka:9092 \
  --describe --group <topic-name>
```

If LAG drops to 0, the service received the message. If LAG stays at 1, the service is not connecting or not consuming.

---

## Inspecting a message in Kafdrop

Kafdrop (web UI) is the easiest way to read a message payload. Use an SSH tunnel on port 19000.

**Local machine — open the tunnel:**

```bash
ssh -i <path-to-ssh-key> -p <ssh-port> \
  -L 19000:127.0.0.1:19000 \
  <user>@<server-ip> -N
```

Then open `http://localhost:19000` in a browser.

Navigate to the topic → **View Messages** → set offset and count → **View Messages**.

The `document` field in print queue messages is a base64-encoded PDF. The `port_name` field is the target printer name sent from ADempiere.

---

## Kafka log level

The default log level is `WARN`. For debugging, temporarily raise it to `INFO` in `override.env`:

```
KAFKA_LOG_LEVEL=INFO
```

Then regenerate `.env` and recreate the Kafka container:

```bash
sudo ./generate-env.sh
sudo docker compose rm -s -f kafka
sudo docker compose up -d kafka
```

> **Important:** `docker compose restart kafka` does **not** apply environment variable changes. The container must be removed and recreated.

Restore `WARN` after debugging:

```bash
# Remove the KAFKA_LOG_LEVEL=INFO line from override.env, then:
sudo ./generate-env.sh
sudo docker compose rm -s -f kafka
sudo docker compose up -d kafka
```

---

## Additional resources

- [Remote Access — Kafdrop browser UI](./remote-access.md#kafdrop--kafka-topic-browser-port-19000)
- [Services — Kafka and Kafdrop](./services.md#kafka)
- [Debugging Guide](./debugging.md)

---

[Back to README](../README.md) | [Back to Debugging Guide](./debugging.md)
