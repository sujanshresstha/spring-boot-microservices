#!/bin/bash

set -e

echo "🔧 Building Spring Boot Microservices..."

# Function to detect docker-compose command
get_docker_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    elif docker compose version &> /dev/null; then
        echo "docker compose"
    else
        echo "❌ Neither 'docker-compose' nor 'docker compose' found. Please install Docker Compose."
        exit 1
    fi
}

DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
echo "📋 Using: $DOCKER_COMPOSE_CMD"

# Build custom Jenkins image
if [ ! "$(docker images -q myjenkins-blueocean:2.516.1-1 2> /dev/null)" ]; then
    echo "📦 Building custom Jenkins image..."
    if [ -f "deployment/jenkins/Dockerfile" ]; then
        docker build -f deployment/jenkins/Dockerfile -t myjenkins-blueocean:2.516.1-1 .
    else
        echo "⚠️  Jenkins Dockerfile not found, using existing Docker Compose configuration..."
    fi
fi

# Check if infra.yml exists
if [ ! -f "deployment/docker-compose/infra.yml" ]; then
    echo "❌ deployment/docker-compose/infra.yml not found!"
    echo "Looking for alternative compose files..."

    # Check for your existing docker-compose.yml in root
    if [ -f "docker-compose.yml" ]; then
        echo "📋 Found docker-compose.yml in root directory"
        echo "🚀 Starting services..."
        $DOCKER_COMPOSE_CMD up -d
    else
        echo "❌ No Docker Compose file found. Please create one of the following:"
        echo "  - deployment/docker-compose/infra.yml"
        echo "  - docker-compose.yml (in root)"
        exit 1
    fi
else
    # Start infrastructure
    echo "🚀 Starting infrastructure..."
    cd deployment/docker-compose
    $DOCKER_COMPOSE_CMD -f infra.yml up -d
    cd ../..
fi

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to start..."
timeout=60
counter=0
until docker exec catalog-db pg_isready -U postgres >/dev/null 2>&1; do
    echo "Waiting for PostgreSQL... ($counter/$timeout seconds)"
    sleep 3
    counter=$((counter + 3))
    if [ $counter -ge $timeout ]; then
        echo "❌ PostgreSQL failed to start within $timeout seconds"
        echo "📋 Checking container logs..."
        docker logs catalog-db --tail 20
        exit 1
    fi
done
echo "✅ PostgreSQL is ready!"

# Wait for Jenkins to start
echo "⏳ Waiting for Jenkins to start..."
timeout=120
counter=0
until curl -f http://localhost:8080/login >/dev/null 2>&1; do
    echo "Waiting for Jenkins... ($counter/$timeout seconds)"
    sleep 5
    counter=$((counter + 5))
    if [ $counter -ge $timeout ]; then
        echo "❌ Jenkins failed to start within $timeout seconds"
        echo "📋 Checking container logs..."
        docker logs jenkins-blueocean --tail 20
        exit 1
    fi
done

echo ""
echo "🎉 Setup completed successfully!"
echo "📊 Jenkins Blue Ocean: http://localhost:8080"
echo "🗄️  PostgreSQL: localhost:15432 (postgres/postgres)"
echo ""
echo "🔍 Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "📝 Next steps:"
echo "1. Access Jenkins and complete initial setup"
echo "2. Create your pipeline job pointing to this repository"
echo "3. Configure GitHub webhook"
echo ""
echo "🔧 Useful commands:"
echo "  View logs: docker logs <container_name>"
echo "  Stop all:  $DOCKER_COMPOSE_CMD down"
echo "  Restart:   $DOCKER_COMPOSE_CMD restart"