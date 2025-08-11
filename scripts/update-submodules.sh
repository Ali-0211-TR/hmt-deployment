#!/bin/bash

# Update Submodules Script
set -e

echo "🔄 Updating HMT Submodules..."

# Function to update a single submodule
update_submodule() {
    local submodule_path=$1
    local submodule_name=$(basename $submodule_path)
    
    if [ -d "$submodule_path" ]; then
        echo "📦 Updating $submodule_name..."
        cd $submodule_path
        
        # Fetch latest changes
        git fetch origin
        
        # Get current branch
        current_branch=$(git branch --show-current)
        
        # Pull latest changes
        if [ -n "$current_branch" ]; then
            git pull origin $current_branch
        else
            # If in detached HEAD state, checkout main/master
            if git show-ref --verify --quiet refs/remotes/origin/main; then
                git checkout main
                git pull origin main
            elif git show-ref --verify --quiet refs/remotes/origin/master; then
                git checkout master
                git pull origin master
            else
                echo "⚠️  No main/master branch found for $submodule_name"
            fi
        fi
        
        cd - > /dev/null
        echo "✅ $submodule_name updated successfully"
    else
        echo "⚠️  Submodule $submodule_name not found at $submodule_path"
    fi
}

# Update all submodules
if [ "$1" = "all" ] || [ -z "$1" ]; then
    echo "🔄 Updating all submodules..."
    
    # Update using git submodule command
    git submodule update --remote --recursive
    
    # Update individual submodules
    update_submodule "services/hmt-apigateway"
    update_submodule "services/hmt-email-service"
    
elif [ "$1" = "apigateway" ] || [ "$1" = "api-gateway" ]; then
    update_submodule "services/hmt-apigateway"
    
elif [ "$1" = "email" ] || [ "$1" = "email-service" ]; then
    update_submodule "services/hmt-email-service"
    
else
    echo "❌ Unknown submodule: $1"
    echo "Usage: $0 [all|apigateway|email]"
    exit 1
fi

# Update the main repository to track the new submodule commits
echo "📝 Updating submodule references..."
git add services/
if git diff --staged --quiet; then
    echo "📋 No submodule updates to commit"
else
    git commit -m "Update submodules to latest versions"
    echo "✅ Submodule references updated and committed"
fi

echo "✅ Submodule update completed successfully!"
echo ""
echo "📋 Next steps:"
echo "   - Review changes: git log --oneline -10"
echo "   - Restart services: ./scripts/dev-start.sh or ./scripts/prod-start.sh"
echo "   - Run tests: ./scripts/test.sh"
