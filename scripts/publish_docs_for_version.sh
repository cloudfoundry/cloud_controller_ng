#!/bin/bash
set -e -x

# This script must be run with an argument: either a final release number or 'release-candidate'

# Write the versionfile in source

ROOT_DIR=$(dirname $0)/..
VERSION=$1

pushd $ROOT_DIR

if [[ $# -eq 0 ]]; then
  echo "You need to provide the version number as the first argument"
  exit 0
fi

cd $ROOT_DIR/docs

touch source/versionfile
echo $VERSION > source/versionfile

# Build the source directory

bundle exec middleman build

# Delete the versionfile

rm -f source/versionfile

popd
# Check out the gh-pages branch

git checkout gh-pages

mv docs/build build

# Copy the build directory into versions/$VERSION/..

if [[ $VERSION != 'release-candidate' && -d version/$VERSION ]]; then
  echo "That version already exists."
  exit 1
fi

if [[ $VERSION == 'release-candidate' ]]; then
  rm -rf version/release-candidate
fi

mkdir -p version/$VERSION
mv build/* version/$VERSION
rm -rf build

# Rewrite the index.html
if [[ $VERSION != 'release-candidate' ]]; then
  rm -f index.html
  touch index.html
  cat <<INDEX > index.html
---
redirect_to: version/$VERSION/index.html
---
INDEX
fi

# Update the versions.json
  # - Grabs all the folder names
  # - Rewrites the versions.json

DIRS=`ls -l version | egrep '^d' | awk '{print $9}' | sort -n -r`

rm -f versions.json
touch versions.json

echo -e '{
\t"versions": [' > versions.json

version_list=''
for DIR in $DIRS
do
  version_list="$version_list\t\t\"$DIR\",\n"
done
# this crazy bash removes the trailing newline and , so that our array is valid json, there's probably a better way
echo -e "${version_list%???}" >> versions.json

echo -e '\t]
}' >> versions.json

# Commit the changes and push to origin/gh-pages
git add index.html --ignore-errors
git add versions.json
git add version/$VERSION
git commit -m "Bump v3 API docs version $VERSION"
git push origin gh-pages

# Check master back out
git checkout master
