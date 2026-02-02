#!/usr/bin/env bash

# Check if repo is dirty
if ! git diff-index --quiet HEAD --; then
    echo "You have uncommitted changes. Please commit or stash them before creating a new release."
    
    # If force is supplied we continue anyways
    if [[ $1 != "--force" ]]; then
      echo "Aborted."
      exit 1
    fi
fi

# Prepare variables for the new tag
nginx_version=$(grep NGINX_VERSION Dockerfile | head -n1 | cut -d '=' -f2)
last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "0")
last_number=$(echo $last_tag | grep -o '[0-9]*$')
if [ -z "$last_number" ]; then last_number=0; fi
new_number=$((last_number + 1))
new_tag="${nginx_version}-${new_number}"

read -p "New tag: ${new_tag}. Is this correct? [y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    # Ask for manual input
    read -p "Please enter the new tag: " new_tag
    
    # Check if the tag is correct
    read -p "New tag: ${new_tag}. Is this correct? [y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        echo "Aborted."
        exit 1
    fi
fi

# Ensure we're logged in on GitHub
if ! gh auth status >/dev/null 2>&1; then
    echo "You need to be logged in on GitHub to create a new release."
    exit 1
fi

# Check if the tag exists locally or remotely
if git rev-parse $new_tag >/dev/null 2>&1 || git ls-remote --tags origin | grep -q $new_tag; then
    echo "Tag $new_tag already exists."
else
    echo "Creating tag $new_tag locally."
    git tag $new_tag
    echo "Tag created. Ready to push and create release."
fi

# Confirm release creation
read -p "Do you want to push tag and create a release for tag $new_tag on GitHub? [y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git push origin $new_tag
    gh release create $new_tag
else
    echo "Aborted."
    exit 1
fi
