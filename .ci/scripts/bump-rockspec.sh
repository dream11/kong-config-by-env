file_name=$(ls *.rockspec)

prefix='config-by-env-'
suffix='-1.rockspec'

version=${file_name#"$prefix"}
version=${version%"$suffix"}

new_version=$1
new_version=${new_version#"v"}

sed -i.bak "s/$version/$new_version/g" $file_name && rm *.bak

new_file_name="$prefix$new_version$suffix"

git config user.name github-actions
git config user.email github-actions@github.com

ACCESS_TOKEN=$2
REPOSITORY=$3
BRANCH=${4:-master}

git remote set-url origin https://x-access-token:$ACCESS_TOKEN@github.com/$REPOSITORY

# Fetch all branches and checkout the target branch
git fetch origin
git checkout $BRANCH

git mv $file_name $new_file_name
git add .
git commit -m "chore: bump version from $version to $new_version"
git push origin $BRANCH
