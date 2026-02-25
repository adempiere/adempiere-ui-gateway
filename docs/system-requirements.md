# System Requirements

This document outlines the system requirements needed to successfully run the ADempiere UI Gateway stack.

## Hardware Requirements

### Minimum Configuration (Testing/Development)

Suitable for testing, development, or small demos with limited data.

| Component | Requirement |
|-----------|-------------|
| **CPU** | 4 cores (2.0 GHz or higher) |
| **RAM** | 8 GB |
| **Disk Space** | 50 GB free space |
| **Disk Type** | HDD acceptable |
| **Network** | 10 Mbps internet connection |

**Expected Performance:**
- Startup time: 2-3 minutes
- Concurrent users: 1-3
- Response time: Acceptable for testing

### Recommended Configuration (Production)

Suitable for production environments with moderate usage.

| Component | Requirement |
|-----------|-------------|
| **CPU** | 8 cores (2.5 GHz or higher) |
| **RAM** | 16 GB (32 GB preferred) |
| **Disk Space** | 200 GB free space (SSD strongly recommended) |
| **Disk Type** | SSD |
| **Network** | 100 Mbps or higher |

**Expected Performance:**
- Startup time: 90-120 seconds
- Concurrent users: 10-20
- Response time: Fast, production-ready

### High-Performance Configuration (Large Deployments)

Suitable for large organizations with many concurrent users.

| Component | Requirement |
|-----------|-------------|
| **CPU** | 16+ cores (3.0 GHz or higher) |
| **RAM** | 32 GB or more |
| **Disk Space** | 500 GB+ SSD |
| **Disk Type** | NVMe SSD |
| **Network** | 1 Gbps dedicated |

**Expected Performance:**
- Startup time: 60-90 seconds
- Concurrent users: 50+
- Response time: Excellent

---

## Software Requirements

### Required Software (Host Machine)

You **MUST** have these installed on your host:

| Software | Minimum Version | Recommended Version |
|----------|----------------|---------------------|
| **Docker** | 20.10 | 24.x (latest stable) |
| **Docker Compose** | v2.16.0 | v2.20+ |
| **Git** | 2.x | 2.40+ |
| **Python** | 3.x | 3.10+ |

### Verify Your Installation

Check installed versions:

```bash
# Docker version
docker --version
# Should show: Docker version 20.10 or higher

# Docker Compose version
docker compose version
# Should show: Docker Compose version v2.16.0 or higher

# Git version
git --version
# Should show: git version 2.x or higher

# Python version
python3 --version
# Should show: Python 3.x or higher
```

### Software You DON'T Need

These run inside containers - **do NOT install on your host:**

- ✗ Java/JDK
- ✗ PostgreSQL
- ✗ nginx
- ✗ Application servers (Tomcat, Jetty, etc.)
- ✗ Node.js (for Vue UI)
- ✗ OpenSearch
- ✗ Kafka

**Security Note:** Keeping these services isolated in containers minimizes your host's attack surface.

---

## Operating System Requirements

### Supported Operating Systems

| OS | Versions | Status |
|----|----------|--------|
| **Ubuntu** | 20.04 LTS, 22.04 LTS, 24.04 LTS | ✅ Recommended |
| **Debian** | 11 (Bullseye), 12 (Bookworm) | ✅ Recommended |
| **RHEL/Rocky/Alma** | 8.x, 9.x | ✅ Supported |
| **CentOS** | 8+ (CentOS Stream) | ✅ Supported |
| **Fedora** | 36+ | ✅ Supported |
| **Other Linux** | With Docker support | ⚠️ May work, not tested |
| **macOS** | Docker Desktop | ⚠️ Works, but slower (virtualization overhead) |
| **Windows** | WSL2 + Docker Desktop | ⚠️ Works, but complex setup |

**Production Recommendation:** Ubuntu 22.04 LTS or Debian 12 for best stability and long-term support.

### Kernel Requirements

- **Minimum kernel:** 3.10 (for Docker)
- **Recommended kernel:** 5.4+ (better performance and security)

Check your kernel version:
```bash
uname -r
# Should show 5.4 or higher for best results
```

---

## Disk Space Planning

### Initial Installation

| Component | Space Required |
|-----------|---------------|
| Docker images | ~15 GB |
| PostgreSQL database (empty) | ~500 MB |
| Container volumes | ~2 GB |
| **Total initial** | **~18 GB** |

### Growth Planning

Plan for database growth over time:

| Usage Scenario | Growth Rate (Monthly) | 1 Year Projection |
|----------------|----------------------|-------------------|
| Small business (1-5 users) | 1-2 GB | 12-24 GB |
| Medium business (10-20 users) | 5-10 GB | 60-120 GB |
| Large business (50+ users) | 20-50 GB | 240-600 GB |

**Recommendation:** Provision **3x** your estimated 1-year database size for:
- Database growth
- Backups
- Logs
- Temporary files

**Example:** If you estimate 100 GB database after 1 year, allocate **300 GB total disk space**.

### Backup Space

Additional space needed for backups:

- **Full backup:** Same size as database
- **Incremental backups:** 10-20% of database size per backup
- **Recommended:** Keep at least 3 full backups

**Example:** 100 GB database = 300 GB for backups (3x full backups)

---

## Network Requirements

### Bandwidth

| Deployment Type | Minimum | Recommended |
|----------------|---------|-------------|
| **Local testing** | 10 Mbps | 50 Mbps |
| **Remote access (few users)** | 50 Mbps | 100 Mbps |
| **Production (many users)** | 100 Mbps | 1 Gbps |

### Ports Required

The following ports are used by default (configurable in `env_template.env`):

| Service | Default Port | Exposed to Internet? | Purpose |
|---------|--------------|---------------------|---------|
| nginx (HTTP) | 80 | Yes | Main application access |
| PostgreSQL | 55432 | **No** (development only) | Database access |
| OpenSearch Dashboard | 5601 | No | Monitoring |
| Kafdrop | 19000 | No | Kafka monitoring |
| DKron | 8899 | No | Scheduler monitoring |
| MinIO Console | 9090 | No | S3 storage browser |

**Security Warning:** Only port 80 (nginx) should be exposed to the internet. All other ports should be protected by a firewall. See [Security Documentation](./security.md) for details.

### Firewall Considerations

**CRITICAL:** Docker bypasses host firewall rules (UFW, firewalld, etc.) by manipulating iptables directly.

**Required security:**
- Use an external firewall (cloud provider firewall, hardware firewall)
- Never expose the host directly to the internet
- See [Security Documentation](./security.md) for detailed guidance

---

## Memory Allocation by Service

Understanding memory usage helps plan capacity:

| Service | Typical Memory Usage |
|---------|---------------------|
| PostgreSQL | 1-2 GB |
| OpenSearch | 2-4 GB |
| Kafka + Zookeeper | 1-2 GB |
| ADempiere ZK | 1-2 GB |
| Vue UI + Backend | 1-2 GB |
| nginx + Envoy | 200-500 MB |
| Other services | 2-3 GB |
| **Total** | **8-15 GB** |

**Note:** These are typical values. Actual usage varies with load and data volume.

---

## Performance Optimization Tips

### For Better Performance

1. **Use SSD storage** - 5-10x faster than HDD for database operations
2. **Allocate more RAM** - Reduces disk I/O, speeds up caching
3. **Use dedicated CPU cores** - Avoid oversubscribing
4. **Fast network** - Important for remote access
5. **Regular maintenance** - Vacuum PostgreSQL, clean Docker cache

### Expected Startup Times

Normal startup times for services (from health checks):

| Service | Typical Startup Time |
|---------|---------------------|
| PostgreSQL | 10-20 seconds |
| nginx, Envoy | 5-10 seconds |
| OpenSearch | 60-120 seconds (normal for Java services) |
| Kafka | 60-90 seconds (normal for Java services) |
| ADempiere ZK | 30-60 seconds |
| Vue UI | 10-20 seconds |

**Total stack startup:** 90-120 seconds is normal and expected.

---

## Pre-Installation Checklist

Before installing, verify you have:

- [ ] Host meets minimum hardware requirements (4 CPU, 8 GB RAM, 50 GB disk)
- [ ] Docker 20.10+ installed and running
- [ ] Docker Compose v2.16.0+ installed
- [ ] Git installed
- [ ] Sufficient disk space planned (including growth)
- [ ] External firewall configured (if exposing to internet)
- [ ] Backup strategy planned
- [ ] Network bandwidth adequate for expected usage

---

## Troubleshooting Common Issues

### "Out of Memory" Errors

**Symptoms:** Containers crashing, slow performance, system freeze

**Solutions:**
- Increase host RAM (minimum 8 GB, recommended 16 GB)
- Reduce number of running services (use specific profiles instead of `all`)
- Configure Docker memory limits
- Close unnecessary applications on host

### "Out of Disk Space" Errors

**Symptoms:** Database restore fails, containers won't start, errors in logs

**Solutions:**
- Check disk space: `df -h`
- Clean Docker cache: `docker system prune -a`
- Delete old backups
- Expand disk partition or add storage

### Slow Performance

**Symptoms:** Application responds slowly, long startup times

**Solutions:**
- Use SSD instead of HDD
- Increase RAM allocation
- Check CPU usage: `top` or `htop`
- Verify network bandwidth
- Run PostgreSQL VACUUM: `docker exec adempiere-ui-gateway.postgresql vacuumdb -U postgres -d adempiere -v -z`

---

## Cloud Provider Recommendations

If deploying to cloud, recommended instance types:

### AWS (Amazon Web Services)
- **Testing:** t3.large (2 vCPU, 8 GB)
- **Production:** t3.xlarge or m5.xlarge (4 vCPU, 16 GB)
- **High-performance:** m5.2xlarge (8 vCPU, 32 GB)

### Digital Ocean
- **Testing:** Basic Droplet - 8 GB RAM
- **Production:** General Purpose - 16 GB RAM
- **High-performance:** CPU-Optimized - 32 GB RAM

### Azure
- **Testing:** Standard_B4ms (4 vCPU, 16 GB)
- **Production:** Standard_D4s_v3 (4 vCPU, 16 GB)
- **High-performance:** Standard_D8s_v3 (8 vCPU, 32 GB)

### Contabo
- **Testing:** VPS S (4 vCPU, 8 GB RAM, 200 GB SSD)
- **Production:** VPS M (6 vCPU, 16 GB RAM, 400 GB SSD)
- **High-performance:** VPS L (8 vCPU, 30 GB RAM, 800 GB SSD)

**Important:** All cloud providers - configure external firewall rules to protect exposed ports!

---

## Next Steps

Once you've verified your system meets these requirements:

1. Proceed to [Installation Guide](./installation.md)
2. Review [Security Documentation](./security.md) before exposing to internet
3. Plan your backup strategy

---

[Back to README](../README.md) | [Previous: Quick Start](./quickstart.md) | [Next: Architecture](./architecture.md)
