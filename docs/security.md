# Security Guide

This guide covers critical security considerations for deploying and operating the ADempiere UI Gateway stack.

⚠️ **IMPORTANT:** This stack is designed for deployment behind a properly configured firewall. Never expose it directly to the public internet without implementing the security measures described below.

## Table of Contents
- [Critical Security Concerns](#critical-security-concerns)
- [Docker Network Security](#docker-network-security)
- [Default Credentials](#default-credentials)
- [Service-Specific Security](#service-specific-security)
- [Network Architecture](#network-architecture)
- [HTTPS/SSL Configuration](#httpsssl-configuration)
- [Secret Management](#secret-management)
- [Access Control](#access-control)
- [Backup Security](#backup-security)
- [Security Best Practices](#security-best-practices)
- [Security Checklist](#security-checklist)

---

## Critical Security Concerns

### 🔴 Docker Bypasses Host Firewall

**The Problem:**

Docker manipulates iptables directly and bypasses UFW/firewall rules configured on the host. When Docker exposes a port (e.g., `80:80`), that port is **immediately accessible** regardless of firewall configuration.

```bash
# Example: Even if UFW blocks port 80...
sudo ufw deny 80

# ...Docker-exposed port 80 is STILL accessible from external networks!
# Docker inserts its own iptables rules that take precedence
```

**Simply put: The host firewall is ineffective against Docker-exposed ports.**

**The Solution:**

You **MUST** implement security at the network level, **before** traffic reaches the host:

1. **Cloud Firewall** (Recommended)
   - AWS Security Groups
   - Digital Ocean Cloud Firewall
   - Azure Network Security Groups
   - Google Cloud Firewall Rules
   - Contabo DDoS Protection + Firewall

2. **Hardware Firewall**
   - Physical firewall appliance
   - Router/gateway firewall
   - Network-level filtering

3. **Never expose host directly to internet**
   - Place behind VPN
   - Use private network/VLAN
   - Implement bastion host/jump server

**Example: Digital Ocean Cloud Firewall Configuration**

![Digital Ocean Firewall Configuration](./security-ports.png)

In this example:
- SSH/SFTP redirected to non-standard port (10099)
- Only necessary ports exposed (HTTP, custom SSH port)
- All other ports blocked at network level

---

## Docker Network Security

### Container Network Isolation

All containers run on an isolated bridge network:

```yaml
# Default: 192.168.100.0/24
networks:
  adempiere_network:
    driver: bridge
    ipam:
      config:
        - subnet: ${NETWORK_SUBNET}  # 192.168.100.0/24
```

**Security benefits:**
- Containers cannot access host network by default
- Services communicate via container names (DNS)
- Internal services not exposed externally unless explicitly mapped

**Security considerations:**
- Change default subnet if it conflicts with your network
- Only expose ports that require external access
- Expose additional ports cautiously (development environments only)

See [Architecture - Network Architecture](./architecture.md#network-architecture) for details.

---

## Default Credentials

⚠️ **CRITICAL:** Change all default credentials before deploying to production!

### Services with Default Credentials

| Service | Default User | Default Password | Environment Variable | Change Priority |
|---------|--------------|------------------|---------------------|-----------------|
| **PostgreSQL** | postgres | postgres | `POSTGRES_PASSWORD` | 🔴 CRITICAL |
| **PostgreSQL** | adempiere | adempiere | `POSTGRES_ADEMPIERE_PASSWORD` | 🔴 CRITICAL |
| **OpenSearch** | admin | admin | `OPENSEARCH_ADMIN_PASSWORD` | 🟡 HIGH |
| **MinIO S3** | minioadmin | minioadmin | `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` | 🟡 HIGH |
| **Keycloak** | admin | admin | `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD` | 🔴 CRITICAL |

See [Services - Service Access Summary](./services.md#service-access-summary) for complete service list.

### How to Change Credentials

1. **Edit `docker-compose/env_template.env`:**

   ```bash
   # PostgreSQL
   POSTGRES_PASSWORD=your-strong-password-here
   POSTGRES_ADEMPIERE_PASSWORD=your-adempiere-password-here

   # OpenSearch
   OPENSEARCH_ADMIN_PASSWORD=your-opensearch-password-here

   # MinIO S3
   MINIO_ROOT_USER=your-minio-username
   MINIO_ROOT_PASSWORD=your-minio-password

   # Keycloak (if using auth profile)
   KEYCLOAK_ADMIN=your-keycloak-admin
   KEYCLOAK_ADMIN_PASSWORD=your-keycloak-password
   ```

2. **Recreate affected containers:**

   ```bash
   cd docker-compose/
   ./stop-all.sh
   ./start-all.sh
   ```

**Password Requirements:**
- Minimum 16 characters
- Mix of uppercase, lowercase, numbers, symbols
- No dictionary words
- Unique per service
- Store securely (password manager)

### ADempiere Application Credentials

ADempiere has its own user management system stored in the database:

- **Default SuperUser:** `SuperUser` / `System`
- **Default Admin:** `GardenAdmin` / `GardenAdmin`

**Change these immediately after first login** through the ADempiere UI:
1. Login as SuperUser
2. Navigate to User Management
3. Change passwords for all default users
4. Create new admin users with strong passwords

---

## Service-Specific Security

### 🔴 CRITICAL: Processor Service

**Never expose the Processor Service externally!**

The Processor Service allows:
- Execution of arbitrary code
- Scheduled task creation
- System-level operations
- Database access

**Security measures:**
- No external ports exposed (by design)
- Internal-only access via Docker network
- Only gRPC services communicate with Processor
- Never add port mappings to this service

If compromised, an attacker could:
- Execute malicious code
- Modify database
- Exfiltrate data
- Compromise entire system

**Verification:**

```bash
# Ensure Processor has no external ports
docker compose ps | grep processor

# Should show: "adempiere-ui-gateway.processor" with NO port mappings
# Correct: No ports listed
# Wrong: "0.0.0.0:XXXX->YYYY/tcp"
```

### PostgreSQL Database

**Security measures:**

1. **Network isolation:**
   - Default: internal only (no external DB port)
   - Development: port 55432 exposed for debugging only
   - Production: Never expose externally

2. **Access control:**
   ```bash
   # Production: default startup; the DB port is controlled in .env
   ./start-all.sh

   # Development: same startup — set POSTGRES_EXTERNAL_PORT in .env to publish port 55432
   ./start-all.sh
   ```

3. **Firewall rules:**
   - If port 55432 exposed, restrict to specific IPs (admin workstations)
   - Never allow public access to PostgreSQL port

4. **Backup encryption:**
   - See [Backup Security](#backup-security) below

### nginx API Gateway

**Security measures:**

1. **Reverse proxy protection:**
   - Single entry point for all services
   - URL-based routing prevents direct service access
   - Can implement rate limiting
   - Can add authentication layer

2. **Configuration security:**
   ```bash
   # Review nginx configuration
   docker exec adempiere-ui-gateway.nginx-ui-gateway cat /etc/nginx/nginx.conf

   # Test configuration
   docker exec adempiere-ui-gateway.nginx-ui-gateway nginx -t
   ```

3. **Future enhancements:**
   - Add ModSecurity WAF
   - Implement rate limiting
   - Add request validation
   - Enable access logging for security monitoring

### OpenSearch

**Security considerations:**

1. **Default credentials:** admin/admin (change in production)
2. **Dashboards access:** Only expose in development environments
3. **Production:** Do not expose dashboards
4. **Data sensitivity:** Contains dictionary metadata (not business data)

### MinIO S3 Storage

**Security considerations:**

1. **Default credentials:** minioadmin/minioadmin (change immediately)
2. **Bucket policies:** Configure access control per bucket
3. **Encryption:** Enable at-rest encryption for sensitive files
4. **Console access:** Port 9090 should be restricted to admins only

### Keycloak (Optional)

**Security considerations:**

1. **SSO security:** Keycloak manages all authentication
2. **LDAP/AD integration:** Use encrypted connections (LDAPS)
3. **Default admin:** Change immediately after first deployment
4. **Realm configuration:** Implement strong password policies
5. **OAuth2/SAML:** Configure with production-grade keys

---

## Network Architecture

### Production Deployment Pattern

```
Internet
   ↓
[Cloud Firewall] ← Only allows ports 80, 443, custom SSH
   ↓
[Bastion/Jump Server] ← SSH access only
   ↓
[Docker Host] ← All services running
   ↓
[nginx:80] ← Single entry point
   ↓
Internal Docker Network (192.168.100.0/24)
   ├── ZK UI (internal only)
   ├── Vue UI (internal only)
   ├── gRPC Services (internal only)
   ├── PostgreSQL (internal only)
   ├── Kafka (internal only)
   └── Processor Service (internal only)
```

### Port Exposure Strategy

**Production setup:**
- **Port 80 (HTTP):** nginx API gateway ONLY
- **No other ports exposed**
- All services accessed via nginx reverse proxy

**Development setup:**
- Port 80: nginx
- Port 55432: PostgreSQL (⚠️ development only)
- Port 5601: OpenSearch Dashboards (⚠️ development only)
- Port 19000: Kafdrop (⚠️ development only)
- Port 9090: MinIO Console (⚠️ development only)
- Port 8899: DKron (⚠️ development only)

**Firewall Rules (Cloud/Hardware):**

```
Production:
- Allow: 80/tcp (HTTP) from anywhere
- Allow: 443/tcp (HTTPS) from anywhere  ← after SSL setup
- Allow: 22/tcp or custom (SSH) from admin IPs only
- Deny: All other ports

Development (additional):
- Allow: 55432/tcp (PostgreSQL) from admin IPs only
- Allow: 5601/tcp (OpenSearch) from admin IPs only
- Allow: 19000/tcp (Kafdrop) from admin IPs only
- Allow: 9090/tcp (MinIO) from admin IPs only
- Allow: 8899/tcp (DKron) from admin IPs only
```

---

## HTTPS/SSL Configuration

⚠️ **The stack runs on HTTP (port 80) only.** Native HTTPS is not yet built in — the community is actively working on it. The workarounds below provide HTTPS in the meantime.

### Why HTTPS is Important

- Encrypts data in transit
- Prevents man-in-the-middle attacks
- Required for PCI compliance (if processing payments)
- Required for GDPR compliance
- Builds user trust

### Implementation Options

#### Option 1: Let's Encrypt with Certbot (Recommended)

**Advantages:**
- Free SSL certificates
- Automatic renewal
- Widely trusted

**Implementation:**

1. **Prerequisites:**
   - Domain name pointing to your server
   - Ports 80 and 443 open in cloud firewall

2. **Install Certbot on host:**
   ```bash
   sudo apt update
   sudo apt install certbot python3-certbot-nginx
   ```

3. **Obtain certificate:**
   ```bash
   sudo certbot certonly --standalone -d yourdomain.com
   ```

4. **Mount certificates into nginx container:**
   ```yaml
   # In docker-compose.yml, nginx service:
   volumes:
     - /etc/letsencrypt:/etc/letsencrypt:ro
   ```

5. **Update nginx configuration:**
   ```nginx
   server {
       listen 443 ssl;
       server_name yourdomain.com;

       ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

       # ... rest of configuration
   }

   # Redirect HTTP to HTTPS
   server {
       listen 80;
       server_name yourdomain.com;
       return 301 https://$server_name$request_uri;
   }
   ```

6. **Setup auto-renewal:**
   ```bash
   sudo crontab -e
   # Add:
   0 3 * * * certbot renew --quiet --post-hook "docker compose -f /path/to/docker-compose.yml restart nginx-ui-gateway"
   ```

#### Option 2: Cloudflare Proxy (Easy Alternative)

**Advantages:**
- Free SSL certificate
- DDoS protection
- CDN included
- No server configuration needed

**Implementation:**

1. Point your domain to Cloudflare nameservers
2. Add A record pointing to your server IP
3. Enable "Proxied" (orange cloud icon)
4. SSL/TLS mode: "Flexible" (Cloudflare ↔ User encrypted, Cloudflare ↔ Server unencrypted)

**Note:** This provides encryption between users and Cloudflare, but not between Cloudflare and your server. For full encryption, use "Full" or "Full (strict)" mode with Option 1.

#### Option 3: Corporate/Commercial Certificate

For enterprise deployments with existing PKI:

1. Obtain certificate from your CA
2. Mount certificate files into nginx container
3. Configure nginx to use them
4. Manage renewal according to your CA's process

---

## Secret Management

### Environment Variables

**Sensitive variables in `env_template.env`:**

```bash
# Database
POSTGRES_PASSWORD=***
POSTGRES_ADEMPIERE_PASSWORD=***

# OpenSearch
OPENSEARCH_ADMIN_PASSWORD=***

# MinIO
MINIO_ROOT_USER=***
MINIO_ROOT_PASSWORD=***

# Keycloak
KEYCLOAK_ADMIN_PASSWORD=***
```

**Security measures:**

1. **Never commit `.env` to version control:**
   ```bash
   # Verify .gitignore includes:
   cat .gitignore | grep ".env"
   # Should show: .env
   ```

2. **Restrict file permissions:**
   ```bash
   chmod 600 docker-compose/.env
   chmod 600 docker-compose/env_template.env  # if contains real passwords
   ```

3. **Use secret management service (advanced):**
   - HashiCorp Vault
   - AWS Secrets Manager
   - Azure Key Vault
   - Docker Secrets (Swarm mode)

### Backup Files

Backup files contain **complete database dumps** including:
- User credentials (hashed)
- Business data
- Configuration settings
- Potentially sensitive information

**Security measures:**

1. **Restrict backup directory access:**
   ```bash
   chmod 700 docker-compose/postgresql/postgres_backups
   chmod 600 docker-compose/postgresql/postgres_backups/*.backup*
   ```

2. **Encrypt backups at rest:**
   ```bash
   # Encrypt backup
   gpg --symmetric --cipher-algo AES256 adempiere-backup.backup.gz

   # Decrypt when needed
   gpg --decrypt adempiere-backup.backup.gz.gpg > adempiere-backup.backup.gz
   ```

3. **Secure offsite storage:**
   - Use encrypted transport (SCP, SFTP, HTTPS)
   - Store in encrypted buckets (S3 with encryption)
   - Restrict access with IAM policies

See [Backup and Restore - Offsite Backups](./backup-restore.md#offsite-backup-options) for implementation details.

---

## Access Control

### SSH Access

1. **Disable password authentication:**
   ```bash
   # /etc/ssh/sshd_config
   PasswordAuthentication no
   PubkeyAuthentication yes
   PermitRootLogin no
   ```

2. **Use SSH keys only:**
   ```bash
   ssh-keygen -t ed25519 -C "admin@yourdomain.com"
   ssh-copy-id -i ~/.ssh/id_ed25519.pub user@server
   ```

3. **Change default SSH port (optional but recommended):**
   ```bash
   # /etc/ssh/sshd_config
   Port 10099  # or any non-standard port
   ```

4. **Implement fail2ban:**
   ```bash
   sudo apt install fail2ban
   sudo systemctl enable fail2ban
   ```

### Docker Access

1. **Restrict Docker socket access:**
   ```bash
   # Only allow specific users in docker group
   sudo usermod -aG docker youradmin

   # Verify
   ls -l /var/run/docker.sock
   # Should show: srw-rw---- 1 root docker
   ```

2. **Never expose Docker socket externally**
   - Do not bind Docker socket to TCP
   - Do not expose Docker API port 2375/2376
   - Use SSH tunneling for remote management

### Service Access

1. **Admin interfaces:**
   - OpenSearch Dashboards (5601): Admin IPs only
   - MinIO Console (9090): Admin IPs only
   - Kafdrop (19000): Admin IPs only
   - DKron (8899): Admin IPs only

2. **Database access:**
   - PostgreSQL port (55432): Never expose in production
   - If absolutely necessary: Restrict to specific admin IPs
   - Use SSH tunneling as alternative:
     ```bash
     ssh -L 5432:localhost:55432 user@server
     # Then connect to localhost:5432
     ```

3. **Application access:**
   - ZK/Vue UIs: Available to all users (via nginx port 80/443)
   - Implement application-level authentication (Keycloak)

---

## Backup Security

See [Backup and Restore Guide](./backup-restore.md) for complete procedures.

### Backup Protection Measures

1. **Access control:**
   ```bash
   # Restrict backup directory
   chmod 700 postgresql/postgres_backups
   chown youradmin:youradmin postgresql/postgres_backups
   ```

2. **Encryption:**
   ```bash
   # Automated encrypted backup
   ./docs/scripts/04-backup-database.sh
   gpg --symmetric --cipher-algo AES256 \
     postgresql/postgres_backups/adempiere-*.backup.gz
   ```

3. **Offsite backup:**
   ```bash
   # Upload to encrypted S3 bucket
   aws s3 cp adempiere-backup.backup.gz.gpg \
     s3://your-encrypted-bucket/backups/ \
     --server-side-encryption AES256
   ```

4. **Backup verification:**
   - Test restore procedures regularly
   - Verify backup integrity
   - Maintain backup logs

5. **Retention policy:**
   - Local: 30 days (automated via backup script)
   - Offsite: 90 days or per compliance requirements
   - Archive: Annual backups for 7 years (if required)

---

## Security Best Practices

### Operating System

1. **Keep system updated:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Enable automatic security updates:**
   ```bash
   sudo apt install unattended-upgrades
   sudo dpkg-reconfigure -plow unattended-upgrades
   ```

3. **Configure firewall (even though Docker bypasses it):**
   ```bash
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow 22/tcp  # or your custom SSH port
   sudo ufw enable
   ```

4. **Monitor system logs:**
   ```bash
   journalctl -f  # Real-time
   tail -f /var/log/auth.log  # SSH attempts
   ```

### Docker

1. **Keep Docker updated:**
   ```bash
   sudo apt update && sudo apt upgrade docker-ce docker-ce-cli
   ```

2. **Use specific image versions (not `:latest`):**
   - Already implemented in this stack
   - Example: `postgres:14.5` not `postgres:latest`

3. **Scan images for vulnerabilities:**
   ```bash
   docker scan adempiere/nginx_ui_gateway:1.0.0
   ```

4. **Limit container resources:**
   ```yaml
   # Prevent DoS via resource exhaustion
   services:
     your-service:
       deploy:
         resources:
           limits:
             cpus: '2.0'
             memory: 4G
   ```

5. **Run containers as non-root (where possible):**
   - Already implemented in some services
   - PostgreSQL, nginx run as non-root users

### Application

1. **Regular updates:**
   - Monitor ADempiere releases
   - Update service images when security patches available
   - Test updates in development before production

2. **Audit logging:**
   - Enable ADempiere audit trails
   - Monitor nginx access logs
   - Review PostgreSQL logs regularly

3. **Session management:**
   - Configure session timeouts
   - Implement idle logout
   - Use secure session cookies (requires HTTPS)

4. **Input validation:**
   - ADempiere includes validation
   - Additional validation in custom code
   - Sanitize user inputs

### Monitoring

1. **Log aggregation:**
   - Collect logs from all containers
   - Use ELK stack or similar
   - Set up alerts for suspicious activity

2. **Intrusion detection:**
   - OSSEC or similar IDS
   - Monitor for unauthorized access attempts
   - Alert on unusual patterns

3. **Security scanning:**
   - Regular vulnerability scans
   - Penetration testing (authorized)
   - Dependency scanning for known CVEs

---

## Security Checklist

Use this checklist before going to production:

### Critical (Must Complete)

- [ ] Cloud/network firewall configured (AWS, DO, Azure, etc.)
- [ ] Host not directly exposed to public internet
- [ ] All default passwords changed (PostgreSQL, OpenSearch, MinIO, Keycloak, ADempiere users)
- [ ] SSH password authentication disabled
- [ ] SSH keys configured for all admins
- [ ] Processor Service has no external ports (verify)
- [ ] PostgreSQL has no external port in production
- [ ] Backup directory permissions restricted (chmod 700)
- [ ] `.env` file not committed to version control
- [ ] Backup encryption implemented
- [ ] Offsite backups configured
- [ ] Restore procedure tested

### Important (Strongly Recommended)

- [ ] HTTPS/SSL configured (Let's Encrypt or commercial cert)
- [ ] SSH port changed from default 22
- [ ] fail2ban installed and configured
- [ ] Automatic security updates enabled
- [ ] Backup verification procedure established
- [ ] Disaster recovery plan documented
- [ ] Admin access restricted to specific IPs (cloud firewall rules)
- [ ] Monitoring and alerting configured
- [ ] Log rotation configured
- [ ] Regular update schedule established

### Additional (Nice to Have)

- [ ] Intrusion detection system (IDS) configured
- [ ] Log aggregation system (ELK stack)
- [ ] Docker image vulnerability scanning
- [ ] WAF (Web Application Firewall) configured
- [ ] DDoS protection enabled
- [ ] Security audit completed
- [ ] Penetration testing performed (authorized)
- [ ] Incident response plan documented
- [ ] Security training for administrators

---

## Additional Resources

- **[Services Documentation](./services.md)** - Complete service reference with default credentials
- **[System Requirements](./system-requirements.md)** - Resource planning and cloud provider recommendations
- **[Architecture Documentation](./architecture.md)** - Network architecture and service dependencies
- **[Backup and Restore Guide](./backup-restore.md)** - Backup security and encryption procedures
- **[Troubleshooting Guide](./troubleshooting.md)** - Security-related troubleshooting

### External Resources

- **Docker Security Best Practices:** https://docs.docker.com/engine/security/
- **OWASP Top 10:** https://owasp.org/www-project-top-ten/
- **CIS Docker Benchmark:** https://www.cisecurity.org/benchmark/docker
- **Let's Encrypt:** https://letsencrypt.org/
- **ADempiere Security:** https://adempiere.io/

---

[Back to README](../README.md) | [Previous: Services](./services.md) | [Next: Backup and Restore](./backup-restore.md)

