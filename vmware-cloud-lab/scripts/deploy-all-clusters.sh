#!/bin/bash
# deploy-all-clusters.sh - One-click production deployment

echo "🚀 VMware Cloud Lab - Production Deployment"
echo "============================================="

# Check if golden images exist
check_golden_images() {
    local missing=0
    
    if [ ! -f "$HOME/Golden-Images/postgres-golden-latest.vmdk" ]; then
        echo "❌ PostgreSQL golden image missing"
        missing=1
    fi
    
    if [ ! -f "$HOME/Golden-Images/oracle-golden-latest.vmdk" ]; then
        echo "❌ Oracle golden image missing"
        missing=1
    fi
    
    if [ ! -f "$HOME/Golden-Images/redhat-mysql-golden-latest.vmdk" ]; then
        echo "❌ MySQL golden image missing"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        echo "🔧 Building missing golden images..."
        build_golden_images
    else
        echo "✅ All golden images found"
    fi
}

# Build all golden images
build_golden_images() {
    echo "📦 Building golden images in parallel..."
    
    ./02-ubuntu-postgres-golden/scripts/build-postgres-golden.sh &
    PG_PID=$!
    
    ./03-oracle-linux-golden/scripts/build-oracle-golden.sh &
    ORA_PID=$!
    
    ./04-redhat-mysql-golden/scripts/build-mysql-golden.sh &
    MYSQL_PID=$!
    
    echo "⏳ Waiting for golden images to complete..."
    wait $PG_PID $ORA_PID $MYSQL_PID
    
    echo "✅ All golden images built successfully"
}

# Deploy all clusters
deploy_clusters() {
    echo "🏗️ Deploying production clusters..."
    
    # Deploy PostgreSQL (fastest)
    echo "📊 Deploying PostgreSQL cluster..."
    ./02-ubuntu-postgres-golden/scripts/deploy-postgres-cluster.sh &
    PG_DEPLOY_PID=$!
    
    # Deploy Oracle (medium)
    echo "🗄️ Deploying Oracle cluster..."
    ./03-oracle-linux-golden/scripts/deploy-oracle-cluster.sh &
    ORA_DEPLOY_PID=$!
    
    # Deploy MySQL HA (medium)
    echo "🔄 Deploying MySQL HA cluster..."
    ./04-redhat-mysql-golden/scripts/deploy-mysql-cluster.sh &
    MYSQL_DEPLOY_PID=$!
    
    # Wait for all deployments
    echo "⏳ Waiting for all clusters to deploy..."
    wait $PG_DEPLOY_PID $ORA_DEPLOY_PID $MYSQL_DEPLOY_PID
    
    echo "✅ All clusters deployed successfully"
}

# Health check all clusters
health_check_all() {
    echo "🔍 Running health checks on all clusters..."
    
    # PostgreSQL health check
    echo "📊 PostgreSQL Health:"
    if psql -h 192.168.200.10 -U postgres -d appdb -c "SELECT 'PostgreSQL OK';" &>/dev/null; then
        echo "  ✅ PostgreSQL cluster healthy"
    else
        echo "  ❌ PostgreSQL cluster issues"
    fi
    
    # Oracle health check
    echo "🗄️ Oracle Health:"
    if sqlplus -s appuser/app123@192.168.300.10:1521/XE <<< "SELECT 'Oracle OK' FROM dual; EXIT;" &>/dev/null; then
        echo "  ✅ Oracle cluster healthy"
    else
        echo "  ❌ Oracle cluster issues"
    fi
    
    # MySQL health check
    echo "🔄 MySQL Health:"
    if mysql -h 192.168.400.200 -u root -p'MySQL123!' -e "SELECT 'MySQL OK';" &>/dev/null; then
        echo "  ✅ MySQL HA cluster healthy"
    else
        echo "  ❌ MySQL HA cluster issues"
    fi
}

# Main execution
main() {
    local start_time=$(date +%s)
    
    case "$1" in
        "build")
            build_golden_images
            ;;
        "deploy")
            check_golden_images
            deploy_clusters
            ;;
        "health")
            health_check_all
            ;;
        "all"|"")
            check_golden_images
            deploy_clusters
            sleep 60
            health_check_all
            ;;
        *)
            echo "Usage: $0 {build|deploy|health|all}"
            exit 1
            ;;
    esac
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "============================================="
    echo "✅ VMware Cloud Lab Complete! Time: ${duration}s"
    echo "📊 PostgreSQL: postgresql://postgres:postgres123@192.168.200.10:5432/appdb"
    echo "🗄️ Oracle: oracle://appuser:app123@192.168.300.10:1521/XE"
    echo "🔄 MySQL: mysql://root:MySQL123!@192.168.400.200:3306/appdb"
    echo "============================================="
}

main "$@"