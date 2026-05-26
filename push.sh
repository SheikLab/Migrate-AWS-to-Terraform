#!/bin/bash

# Ask inputs with defaults
read -p "Enter GitHub Username [SheikLab]: " USERNAME
USERNAME=${USERNAME:-SheikLab}
read -p "Enter Repository Name: " REPONAME

if [ -z "$REPONAME" ]; then
	echo "Repository name is required."
	exit 1
fi

# Create .gitignore if it doesn't exist
if [ ! -f .gitignore ]; then
	echo "Creating .gitignore with security and large file exclusions..."
	cat > .gitignore << 'EOF'
.terraform/
*.pem
terraform.tfstate
terraform.tfstate.backup
.terraform.lock.hcl
EOF
fi

# Initialize git if necessary
if [ ! -d .git ]; then
	git init
fi

# Remove large/sensitive files from git index if previously tracked
echo "Cleaning sensitive and large files from git index..."
git rm -r --cached .terraform 2>/dev/null || true
git rm --cached *.pem terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl 2>/dev/null || true

# Add files (respecting .gitignore)
git add .

# Commit: create initial commit only if repository has no commits yet
if git rev-parse --verify HEAD >/dev/null 2>&1; then
	git commit -m "Update" || true
else
	git commit -m "Initial commit" || true
fi

# Add .gitignore if not already committed
git add .gitignore
git commit -m "Add .gitignore with security exclusions" || true

# Set branch
git branch -M main

# Try to create repository on GitHub using gh CLI (if installed)
if command -v gh >/dev/null 2>&1; then
	if gh repo view "$USERNAME/$REPONAME" >/dev/null 2>&1; then
		echo "Repository $USERNAME/$REPONAME already exists on GitHub."
	else
		echo "Creating GitHub repository: $USERNAME/$REPONAME"
		if ! gh repo create "$USERNAME/$REPONAME" --public --confirm >/dev/null 2>&1; then
			echo "Warning: failed to create repository with gh. You may need to authenticate (gh auth login) or check permissions."
		else
			echo "Repository created on GitHub."
		fi
	fi
else
	echo "gh CLI not found. Skipping automatic GitHub repo creation. Install gh to enable this feature." 
fi

# Set remote (force replace existing origin)
git remote remove origin 2>/dev/null || true
git remote add origin git@github.com:$USERNAME/$REPONAME.git

# Push (force if history was cleaned)
if git log --oneline | grep -q "Remove .terraform\|Add .gitignore"; then
	echo "Pushing with --force (cleaned history)..."
	git push --force -u origin main
else
	git push -u origin main
fi



