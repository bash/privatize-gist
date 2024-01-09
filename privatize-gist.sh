#!/usr/bin/env bash

set -e

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <gist-id>"
    exit 1
fi

old_gist_id="$1"
old_gist=$(gh api "/gists/$old_gist_id")
old_gist_clone_url="git@gist.github.com:$old_gist_id.git"
public=$(echo "$old_gist" | jq --raw-output '.public')
description=$(echo "$old_gist" | jq --raw-output '.description')

if [[ $public != true ]];
then
    echo "Gist is already private"
    exit 1
fi

clone_dir=$(mktemp -d -t "gist.$old_gist_id")
echo "Description: $description"
git clone "$old_gist_clone_url" "$clone_dir" --origin upstream

new_gist_body=$(jq --null-input --arg description "$description" '{"description": $description, files: {"-": {"content": "-" } }, public: false}')
new_gist=$(echo "$new_gist_body" | gh api -X POST "/gists" --input -)
new_gist_id=$(echo "$new_gist" | jq --raw-output '.id')
new_gist_html_url=$(echo "$new_gist" | jq --raw-output '.html_url')
new_gist_clone_url="git@gist.github.com:$new_gist_id.git"

git -C "$clone_dir" remote add origin "$new_gist_clone_url"
git -C "$clone_dir" fetch origin
git -C "$clone_dir" remote set-head -a origin

old_branch_name=$(git -C "$clone_dir" rev-parse --abbrev-ref HEAD)
new_branch_ref=$(git -C "$clone_dir" symbolic-ref refs/remotes/origin/HEAD --short)
new_branch_name=${new_branch_ref#"origin/"}
git -C "$clone_dir" push --force origin "$old_branch_name:$new_branch_name"
rm -rf "$clone_dir"

gh api -X DELETE "/gists/$old_gist_id"

echo "🔐 Gist privatized: $new_gist_html_url"
