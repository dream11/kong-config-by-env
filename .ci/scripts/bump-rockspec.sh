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
git remote set-url origin https://x-access-token:$ACCESS_TOKEN@github.com/kong-config-by-env

git mv $file_name $new_file_name
git checkout test/release
git add .
git commit -m "chore: bump version from $version to $new_version"
git push origin HEAD:test/release
