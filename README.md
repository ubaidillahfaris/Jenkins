# Jenkins Docker Container Setup

Setup Docker container untuk Jenkins dengan Nginx reverse proxy.

## 📋 Prerequisites

- Docker dan Docker Compose terinstall
- Port 80, 443, dan 50000 available
- Minimal 2GB RAM

## 🚀 Quick Start

### 1. Start Jenkins + Nginx

```bash
cd /Volumes/ssd_faruq/Project/docker-container/jenkins

# Build & run
make up

# Atau manual:
docker-compose up -d
```

### 2. Get Initial Password

```bash
make password

# Atau manual:
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 3. Access Jenkins

Buka browser: **http://localhost/jenkins**

Paste initial password dari step 2.

> 💡 **Note**: Jenkins sekarang di-access via Nginx di path `/jenkins`
> Untuk setup HTTPS atau custom domain, lihat [nginx/README.md](nginx/README.md)

### 4. Install Plugins

Pilih **"Install suggested plugins"** - ini akan install plugins standard untuk:
- Git integration
- Pipeline support
- Docker support
- SSH deployment

## 🔧 What's Included

- ✅ Jenkins LTS
- ✅ Nginx reverse proxy dengan SSL support
- ✅ Docker CLI (untuk build images)
- ✅ Docker Compose (untuk deployment)
- ✅ Access ke Docker daemon via socket
- ✅ Persistent data di `jenkins_home/`

## 🦊 GitLab Integration

### Setup GitLab Registry Credentials

1. **Jenkins Dashboard** → **Manage Jenkins** → **Credentials** → **Add Credentials**
2. Pilih **Username with password**:
   - **Username**: GitLab username
   - **Password**: GitLab Personal Access Token (buat di GitLab Settings → Access Tokens)
   - **ID**: `gitlab-registry`

### Example Jenkinsfile dengan GitLab Registry

```groovy
pipeline {
    agent any
    
    environment {
        GITLAB_REGISTRY = 'registry.gitlab.com'
        GITLAB_PROJECT = 'your-username/your-project'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }
    
    stages {
        stage('Build') {
            steps {
                script {
                    docker.build("${GITLAB_REGISTRY}/${GITLAB_PROJECT}:${IMAGE_TAG}")
                }
            }
        }
        
        stage('Push to GitLab Registry') {
            steps {
                script {
                    docker.withRegistry("https://${GITLAB_REGISTRY}", 'gitlab-registry') {
                        docker.image("${GITLAB_REGISTRY}/${GITLAB_PROJECT}:${IMAGE_TAG}").push()
                        docker.image("${GITLAB_REGISTRY}/${GITLAB_PROJECT}:${IMAGE_TAG}").push('latest')
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sh '''
                    ssh user@server "docker pull ${GITLAB_REGISTRY}/${GITLAB_PROJECT}:latest && docker-compose up -d"
                '''
            }
        }
    }
}
```

### Login ke GitLab Registry dari Server

Di server staging/production:

```bash
docker login registry.gitlab.com
Username: your-gitlab-username
Password: your-gitlab-token

# Pull image
docker pull registry.gitlab.com/your-username/your-project:latest
```

## 📝 Common Commands

```bash
make up       # Start Jenkins
make down     # Stop Jenkins
make restart  # Restart Jenkins
make logs     # View logs
make password # Get initial password
make shell    # Open bash in container
```

## 📁 File Structure

```
jenkins/
├── Dockerfile           # Jenkins + Docker CLI + Docker Compose
├── docker-compose.yaml  # Services: Jenkins + Nginx
├── Makefile            # Helper commands
├── README.md           # This file
├── .gitignore          # Ignore sensitive files
├── nginx/              # Nginx reverse proxy config
│   ├── nginx.conf      # Nginx configuration
│   ├── generate-ssl.sh # SSL cert generator
│   ├── README.md       # Nginx setup guide
│   └── ssl/           # SSL certificates (gitignored)
└── jenkins_home/       # Persistent data (gitignored)
```

## 🔐 Security Notes

1. **`.env` dan `jenkins_home/`** sudah di-gitignore
2. Ganti default passwords setelah setup
3. Simpan credentials di Jenkins Credentials Store, jangan hardcode
4. Untuk production, pakai HTTPS dengan reverse proxy (nginx)

## 🛠️ Troubleshooting

### Port 8080 sudah dipakai

```bash
# Check process
lsof -i :8080

# Ganti port di docker-compose.yaml
ports:
  - "9090:8080"  # Ubah 8080 jadi 9090
```

### Permission error dengan Docker socket

```bash
# Check permissions
ls -l /var/run/docker.sock

# Sudah di-handle dengan user: root di docker-compose.yaml
```

### Jenkins lambat/hang

```bash
# Increase memory jika perlu
# Edit docker-compose.yaml, tambah:
environment:
  - JAVA_OPTS=-Xmx2048m -Xms512m
```

## 📚 References

- [Jenkins Docs](https://www.jenkins.io/doc/)
- [GitLab Container Registry](https://docs.gitlab.com/ee/user/packages/container_registry/)
- [Jenkins Docker Plugin](https://plugins.jenkins.io/docker-plugin/)
