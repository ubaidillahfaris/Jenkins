# Setup SSL untuk Jenkins Subdomain

Ada 3 opsi untuk SSL di jenkins.ketjubung.com:

## Option 1: Wildcard Certificate (EASIEST) ✅

Jika cert `ketjubung.crt` adalah wildcard cert `*.ketjubung.com`:

### Check apakah wildcard:
```bash
# Di server
openssl x509 -in /root/project/docker/nginx/ssl/ketjubung.crt -noout -text | grep DNS

# Cari output:
# DNS:*.ketjubung.com atau DNS:ketjubung.com, DNS:*.ketjubung.com
```

### Jika wildcard:
✅ **Langsung bisa pakai!** Cert sudah cover jenkins.ketjubung.com

### Enable HTTPS:
1. Edit `jenkins.conf`
2. Comment HTTP server block (line 3-59)
3. Uncomment HTTPS blocks (line 64-157)
4. Cert path sudah OK (line 77-78 pakai ketjubung.crt)
5. Reload nginx

---

## Option 2: Let's Encrypt (RECOMMENDED untuk Production)

Free SSL dari Let's Encrypt:

### Steps:

**1. Install certbot:**
```bash
# Di server
yum install certbot -y
# atau
dnf install certbot -y
```

**2. Stop nginx sementara:**
```bash
cd /root/project
docker-compose stop web
```

**3. Get certificate:**
```bash
certbot certonly --standalone \
    -d jenkins.ketjubung.com \
    --email your@email.com \
    --agree-tos \
    --non-interactive

# Cert akan ada di:
# /etc/letsencrypt/live/jenkins.ketjubung.com/fullchain.pem
# /etc/letsencrypt/live/jenkins.ketjubung.com/privkey.pem
```

**4. Mount cert ke container:**

Edit `/root/project/docker-compose.yml`:
```yaml
web:
  volumes:
    - ./docker/nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf:ro
    - ./docker/nginx/conf.d/jenkins.conf:/etc/nginx/conf.d/jenkins.conf:ro
    - ./docker/nginx/ssl:/etc/nginx/ssl:ro
    - /etc/letsencrypt:/etc/letsencrypt:ro  # ADD THIS
    - app-data:/var/www/html:ro
```

**5. Update jenkins.conf:**

Uncomment HTTPS block dan update cert path (line 89-90):
```nginx
ssl_certificate /etc/letsencrypt/live/jenkins.ketjubung.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/jenkins.ketjubung.com/privkey.pem;
```

**6. Start nginx:**
```bash
docker-compose up -d
docker exec gresik-web nginx -t
```

**7. Auto-renewal:**
```bash
# Test renewal
certbot renew --dry-run

# Certbot auto-renew via systemd timer
systemctl status certbot-renew.timer
systemctl enable certbot-renew.timer

# Or add cron:
crontab -e
# Add:
0 0,12 * * * certbot renew --quiet --post-hook "docker exec gresik-web nginx -s reload"
```

---

## Option 3: Self-Signed (Development/Testing Only)

Generate self-signed cert (browser akan warning):

```bash
# Di server
cd /root/project/docker/nginx/ssl

# Generate cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout jenkins.ketjubung.key \
    -out jenkins.ketjubung.crt \
    -subj "/C=ID/ST=JawaTimur/L=Gresik/O=Ketjubung/CN=jenkins.ketjubung.com" \
    -extensions SAN \
    -config <(cat /etc/pki/tls/openssl.cnf \
        <(printf "\n[SAN]\nsubjectAltName=DNS:jenkins.ketjubung.com"))

# Update jenkins.conf (uncomment HTTPS, update cert path line 80-81):
# ssl_certificate /etc/nginx/ssl/jenkins.ketjubung.crt;
# ssl_certificate_key /etc/nginx/ssl/jenkins.ketjubung.key;

# Reload
docker exec gresik-web nginx -s reload
```

⚠️ Browser akan warning "Not Secure" - harus click "Proceed Anyway"

---

## Quick Comparison

| Option | Cost | Browser Trust | Auto-Renew | Setup Time |
|--------|------|---------------|------------|------------|
| **Wildcard** | $ | ✅ Yes | Manual | 2 min |
| **Let's Encrypt** | FREE | ✅ Yes | ✅ Auto | 10 min |
| **Self-Signed** | FREE | ❌ No | N/A | 5 min |

**Recommendation:**
- Production: **Let's Encrypt** (free + trusted)
- Development: **Self-Signed** atau langsung HTTP

---

## Enable HTTPS Steps (After cert ready)

Setelah punya cert (any option above):

**1. Edit jenkins.conf:**
```bash
nano /root/project/docker/nginx/conf.d/jenkins.conf
```

**2. Comment HTTP server block:**
```nginx
# server {
#     listen 80;
#     server_name jenkins.ketjubung.com;
#     ...entire block...
# }
```

**3. Uncomment HTTPS blocks:**
- HTTP to HTTPS redirect (line ~67-71)
- HTTPS server block (line ~73-157)

**4. Update cert paths** (line 77-78 atau sesuai option):
```nginx
ssl_certificate /path/to/cert.pem;
ssl_certificate_key /path/to/key.pem;
```

**5. Test & reload:**
```bash
docker exec gresik-web nginx -t
docker exec gresik-web nginx -s reload
```

**6. Test access:**
```bash
curl -IL http://jenkins.ketjubung.com
# Should redirect to HTTPS

curl -IL https://jenkins.ketjubung.com/jenkins
# Should return 200 OK
```

---

## Troubleshooting

### "SSL certificate problem"
```bash
# Check cert exists
docker exec gresik-web ls -la /etc/nginx/ssl/
docker exec gresik-web ls -la /etc/letsencrypt/live/

# Check cert valid
openssl x509 -in /path/to/cert.pem -noout -text
```

### "Name does not resolve"
```bash
# Check cert CN/SAN matches domain
openssl x509 -in /path/to/cert.pem -noout -text | grep -E "Subject:|DNS:"
```

### Let's Encrypt rate limit
- 50 certs/week per domain
- Use `--staging` flag for testing:
```bash
certbot certonly --standalone --staging -d jenkins.ketjubung.com
```

---

## My Recommendation

**Start Simple:**
1. ✅ Deploy HTTP first (current jenkins.conf)
2. ✅ Test Jenkins accessible: http://jenkins.ketjubung.com/jenkins
3. ✅ Setup Let's Encrypt SSL (10 minutes)
4. ✅ Enable HTTPS in jenkins.conf
5. ✅ Done!

Mau saya buatkan script auto-setup Let's Encrypt?
