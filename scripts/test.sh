#!/bin/bash

# Test HMT Deployment
set -e

echo "🧪 Testing HMT Deployment..."

# Default parameters
COMPOSE_FILE="docker-compose.dev.yml"
TEST_TYPE="all"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prod)
            COMPOSE_FILE="docker-compose.yml"
            shift
            ;;
        --type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --prod               Test production environment"
            echo "  --type TYPE          Test type: all, unit, integration, e2e"
            echo "  -h, --help           Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Load environment variables
if [ -f ".env" ]; then
    source .env
fi

echo "📊 Test Configuration:"
echo "  - Compose file: $COMPOSE_FILE"
echo "  - Test type: $TEST_TYPE"
echo ""

# Function to run tests in a service
run_service_tests() {
    local service=$1
    local test_command=$2
    
    echo "🧪 Running tests for $service..."
    
    if docker-compose -f $COMPOSE_FILE ps | grep -q "$service.*Up"; then
        docker-compose -f $COMPOSE_FILE exec $service $test_command
        if [ $? -eq 0 ]; then
            echo "✅ $service tests passed"
            return 0
        else
            echo "❌ $service tests failed"
            return 1
        fi
    else
        echo "⚠️  $service is not running, skipping tests"
        return 1
    fi
}

# Function to test API endpoints
test_api_endpoints() {
    echo "🌐 Testing API endpoints..."
    
    local api_url="http://localhost:${API_GATEWAY_PORT:-3000}"
    local tests_passed=0
    local tests_total=0
    
    # Test health endpoint
    echo "  - Testing health endpoint..."
    ((tests_total++))
    if curl -f -s "$api_url/health" > /dev/null; then
        echo "    ✅ Health endpoint responding"
        ((tests_passed++))
    else
        echo "    ❌ Health endpoint failed"
    fi
    
    # Test API documentation
    echo "  - Testing API documentation..."
    ((tests_total++))
    if curl -f -s "$api_url/docs" > /dev/null; then
        echo "    ✅ API documentation accessible"
        ((tests_passed++))
    else
        echo "    ❌ API documentation failed"
    fi
    
    # Test authentication endpoint
    echo "  - Testing authentication..."
    ((tests_total++))
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$api_url/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"email":"test@example.com","password":"wrongpassword"}')
    
    if [ "$response" = "401" ]; then
        echo "    ✅ Authentication endpoint responding correctly"
        ((tests_passed++))
    else
        echo "    ❌ Authentication endpoint unexpected response: $response"
    fi
    
    echo "  📊 API tests: $tests_passed/$tests_total passed"
    return $((tests_total - tests_passed))
}

# Function to test gRPC endpoints
test_grpc_endpoints() {
    echo "🔌 Testing gRPC endpoints..."
    
    local grpc_port=${EMAIL_SERVICE_GRPC_PORT:-5000}
    
    # Test if gRPC port is accessible
    if nc -z localhost $grpc_port; then
        echo "  ✅ gRPC port $grpc_port is accessible"
        return 0
    else
        echo "  ❌ gRPC port $grpc_port is not accessible"
        return 1
    fi
}

# Function to test database connectivity
test_database() {
    echo "🗄️  Testing database connectivity..."
    
    # Test PostgreSQL
    if docker-compose -f $COMPOSE_FILE exec -T postgres pg_isready -q; then
        echo "  ✅ PostgreSQL is accessible"
    else
        echo "  ❌ PostgreSQL connection failed"
        return 1
    fi
    
    # Test Redis
    if docker-compose -f $COMPOSE_FILE exec -T redis redis-cli ping | grep -q "PONG"; then
        echo "  ✅ Redis is accessible"
    else
        echo "  ❌ Redis connection failed"
        return 1
    fi
    
    return 0
}

# Function to test service performance
test_performance() {
    echo "⚡ Testing service performance..."
    
    local api_url="http://localhost:${API_GATEWAY_PORT:-3000}"
    
    # Test response time
    echo "  - Testing response time..."
    local response_time=$(curl -o /dev/null -s -w "%{time_total}" "$api_url/health")
    
    if (( $(echo "$response_time < 1.0" | bc -l) )); then
        echo "    ✅ Response time: ${response_time}s (good)"
    elif (( $(echo "$response_time < 3.0" | bc -l) )); then
        echo "    ⚠️  Response time: ${response_time}s (acceptable)"
    else
        echo "    ❌ Response time: ${response_time}s (poor)"
        return 1
    fi
    
    return 0
}

# Function to run load test
run_load_test() {
    echo "🚀 Running load test..."
    
    local api_url="http://localhost:${API_GATEWAY_PORT:-3000}"
    
    # Simple load test with curl
    echo "  - Testing with 10 concurrent requests..."
    
    for i in {1..10}; do
        curl -s "$api_url/health" > /dev/null &
    done
    
    wait
    echo "  ✅ Load test completed"
}

# Main test execution
main() {
    local overall_result=0
    
    echo "🔍 Starting tests..."
    echo ""
    
    # Check if services are running
    if ! docker-compose -f $COMPOSE_FILE ps | grep -q "Up"; then
        echo "❌ No services are running. Please start the environment first."
        echo "   Development: ./scripts/dev-start.sh"
        echo "   Production:  ./scripts/prod-start.sh"
        exit 1
    fi
    
    # Wait for services to be ready
    echo "⏳ Waiting for services to be ready..."
    sleep 10
    
    # Run tests based on type
    case $TEST_TYPE in
        "all"|"integration")
            # Database tests
            if ! test_database; then
                ((overall_result++))
            fi
            
            # API endpoint tests
            if ! test_api_endpoints; then
                ((overall_result++))
            fi
            
            # gRPC endpoint tests
            if ! test_grpc_endpoints; then
                ((overall_result++))
            fi
            
            # Performance tests
            if ! test_performance; then
                ((overall_result++))
            fi
            
            if [ "$TEST_TYPE" = "all" ]; then
                # Load test
                run_load_test
            fi
            ;;
            
        "unit")
            # Unit tests for each service
            if ! run_service_tests "api-gateway" "npm test"; then
                ((overall_result++))
            fi
            
            if ! run_service_tests "email-service" "npm test"; then
                ((overall_result++))
            fi
            ;;
            
        "e2e")
            # End-to-end tests
            if ! run_service_tests "api-gateway" "npm run test:e2e"; then
                ((overall_result++))
            fi
            ;;
            
        *)
            echo "❌ Unknown test type: $TEST_TYPE"
            exit 1
            ;;
    esac
    
    echo ""
    echo "📊 Test Summary:"
    
    if [ $overall_result -eq 0 ]; then
        echo "✅ All tests passed successfully!"
        echo ""
        echo "🎉 Your HMT deployment is working correctly!"
    else
        echo "❌ Some tests failed ($overall_result failures)"
        echo ""
        echo "🔍 Debugging suggestions:"
        echo "  - Check service logs: ./scripts/logs.sh"
        echo "  - Run health check: ./scripts/health-check.sh"
        echo "  - Check service status: docker-compose ps"
        echo "  - Review configuration: cat .env"
    fi
    
    exit $overall_result
}

# Run main function
main
