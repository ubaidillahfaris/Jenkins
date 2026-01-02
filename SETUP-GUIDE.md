# Setup Jenkins dengan Nginx Existing (gresik-web)

## 🎯 Current Setup
- ✅ Jenkins running di port 8080
- ✅ Nginx (gresik-web) running di port 80/443
- ✅ Domain: ketjubung.com
- 🎯 Target: jenkins.ketjubung.com

## 🚀 Setup Steps

### 1. Copy Config ke Server

Upload `jenkins.conf` ke server:

```bash
# Di local (Mac)
scp /Volumes/ssd_faruq/Project/docker-container/jenkins/jenkins.conf \
    root@vpsketjubung:/root/project/docker/nginx/conf.d/jenkins.conf
```

Atau manual di server:
```bash
# Di server
cd /root/project/docker/nginx/conf.d/
nano jenkins.conf
# Paste isi jenkins.conf
```

### 2. Update docker-compose.yml

Edit `/root/project/docker-compose.yml`:

```yaml
web:
  image: nginx:alpine
  container_name: gresik-web
  restart: unless-stopped
  depends_on:
    - app
  ports:
    - "${HTTP_PORT:-80}:80"
    - "${HTTPS_PORT:-443}:443"
  volumes_from:
    - app
  volumes:
    - ./docker/nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf:ro
    - ./docker/nginx/conf.d/jenkins.conf:/etc/nginx/conf.d/jenkins.conf:ro  # ADD THIS LINE
    - ./docker/nginx/ssl:/etc/nginx/ssl:ro
    - app-data:/var/www/html:ro
  networks:
    - app-net
```

### 3. Test Nginx Config

```bash
docker exec gresik-web nginx -t
```

Should return: `syntax is ok` and `test is successful`

### 4. Reload Nginx

```bash
docker exec gresik-web nginx -s reload

# Atau restart container
docker-compose restart web
```

### 5. DNS Setup

Add A record untuk subdomain Jenkins:

```
jenkins.ketjubung.com → A → <server-ip-kamu>
```

Di DNS provider (Cloudflare/Namecheap/dll):
- Type: A
- Name: jenkins
- Value: IP server VPS
- TTL: Auto

### 6. SSL Certificate

**Option 1: Wildcard Cert (Recommended)**

Jika cert `ketjubung.crt` adalah wildcard cert `*.ketjubung.com`:
- ✅ Config sudah OK, langsung restart nginx

**Option 2: Cert Baru untuk Jenkins Subdomain**

Jika perlu cert khusus untuk jenkins.ketjubung.com:

```bash
# Generate SSL cert (self-signed untuk testing)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /root/project/docker/nginx/ssl/jenkins.ketjubung.key \
    -out /root/project/docker/nginx/ssl/jenkins.ketjubung.crt \
    -subj "/C=ID/ST=JawaTimur/L=Gresik/O=Ketjubung/CN=jenkins.ketjubung.com"

# Update jenkins.conf line 15-16:
# ssl_certificate /etc/nginx/ssl/jenkins.ketjubung.crt;
# ssl_certificate_key /etc/nginx/ssl/jenkins.ketjubung.key;

# Reload nginx
docker exec gresik-web nginx -s reload
```

**Option 3: Let's Encrypt (Production)**

```bash
# Install certbot di server
yum install certbot -y

# Stop nginx temporarily
docker-compose stop web

# Get cert
certbot certonly --standalone \
    -d jenkins.ketjubung.com \
    --email your@email.com \
    --agree-tos

# Cert location:
# /etc/letsencrypt/live/jenkins.ketjubung.com/fullchain.pem
# /etc/letsencrypt/live/jenkins.ketjubung.com/privkey.pem

# Update docker-compose.yml untuk mount letsencrypt:
# volumes:
#   - /etc/letsencrypt:/etc/letsencrypt:ro

# Update jenkins.conf:
# ssl_certificate /etc/letsencrypt/live/jenkins.ketjubung.com/fullchain.pem;
# ssl_certificate_key /etc/letsencrypt/live/jenkins.ketjubung.com/privkey.pem;

# Start nginx
docker-compose start web
```

### 7. Test Access

```bash
# Test dari server
curl -I http://jenkins.ketjubung.com
# Should return: 301 → https://

curl -I https://jenkins.ketjubung.com
# Should return: 301 → /jenkins

curl -I https://jenkins.ketjubung.com/jenkins
# Should return: 200 OK

# Test dari browser
# https://jenkins.ketjubung.com
```

## 🔧 Troubleshooting

### 1. "502 Bad Gateway"

Jenkins tidak reachable dari nginx container.

**Check Jenkins running:**
```bash
curl http://localhost:8080/jenkins
```

**Check from nginx container:**
```bash
docker exec gresik-web ping 172.17.0.1
docker exec gresik-web wget -O- http://172.17.0.1:8080/jenkins
```

**If failed, update jenkins.conf dengan IP server:**
```bash
# Get server IP
ip addr show

# Update jenkins.conf line 69:
# proxy_pass http://192.168.1.100:8080/jenkins;  # Replace with actual IP
```

### 2. "SSL certificate verify failed"

Cert tidak ada atau path salah.

**Check cert exists:**
```bash
ls -la /root/project/docker/nginx/ssl/
docker exec gresik-web ls -la /etc/nginx/ssl/
```

**Check cert valid:**
```bash
openssl x509 -in /root/project/docker/nginx/ssl/ketjubung.crt -noout -text
# Check CN and DNS names
```

### 3. DNS not resolving

**Check DNS dari server:**
```bash
dig jenkins.ketjubung.com
nslookup jenkins.ketjubung.com

# Should return server IP
```

**Wait for DNS propagation:**
DNS changes bisa butuh 5-60 menit.

**Test dengan /etc/hosts sementara:**
```bash
# Di local machine
sudo nano /etc/hosts
# Add:
# <server-ip> jenkins.ketjubung.com
```

### 4. Nginx config error

**Test config:**
```bash
docker exec gresik-web nginx -t
```

**Check logs:**
```bash
docker logs gresik-web

# Or
docker exec gresik-web tail -f /var/log/nginx/jenkins.error.log
```

### 5. Firewall blocking

**Check port 8080:**
```bash
firewall-cmd --list-all
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload

# Or
iptables -L -n | grep 8080
```

## 📊 Architecture

```
Internet
    ↓
jenkins.ketjubung.com (DNS)
    ↓
Port 443 (gresik-web nginx container)
    ↓
HTTP → HTTPS redirect
    ↓
HTTPS Server (jenkins.ketjubung.com)
    ↓
Proxy pass → 172.17.0.1:8080
    ↓
Jenkins container (port 8080)
```

## ✅ Verification Checklist

- [ ] jenkins.conf uploaded ke server
- [ ] docker-compose.yml updated dengan jenkins.conf mount
- [ ] Nginx config test passed (`nginx -t`)
- [ ] Nginx reloaded/restarted
- [ ] DNS A record created (jenkins.ketjubung.com)
- [ ] SSL cert ready (wildcard/specific/letsencrypt)
- [ ] HTTP redirects to HTTPS (test with curl)
- [ ] HTTPS returns 200 OK for /jenkins
- [ ] Jenkins accessible via browser
- [ ] Jenkins URL configured in dashboard

## 🎯 Final URLs

- Main app: https://ketjubung.com
- Jenkins: https://jenkins.ketjubung.com/jenkins
- Jenkins direct: http://server-ip:8080/jenkins (for debugging)

## 📝 Notes

1. **Docker network IP**: `172.17.0.1` adalah default Docker bridge gateway. Ini IP host dari perspektif container.

2. **Cert sharing**: Jika ketjubung.crt adalah wildcard cert `*.ketjubung.com`, bisa langsung pakai tanpa generate baru.

3. **Jenkins URL**: Setelah accessible, configure Jenkins URL di:
   - Dashboard → Manage Jenkins → System
   - Jenkins URL: `https://jenkins.ketjubung.com/jenkins/`

4. **Auto-renewal SSL**: Jika pakai Let's Encrypt, setup auto-renewal dengan certbot timer atau cron job.

## 🚀 Quick Commands

```bash
# Full deployment dari awal (di server)
cd /root/project

# 1. Copy jenkins.conf (already done)
# 2. Edit docker-compose.yml (add jenkins.conf mount)
# 3. Test & reload
docker exec gresik-web nginx -t && docker exec gresik-web nginx -s reload

# 4. Test access
curl -IL https://jenkins.ketjubung.com/jenkins

# 5. Check logs
docker logs gresik-web -f
```

Done! 🎉
