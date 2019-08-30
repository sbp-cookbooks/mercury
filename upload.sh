#!/bin/bash -e

git describe --tags --always > .version
echo "path: ${PWD} version: $(cat .version)"



if [ "$1" == "" ]; then
    REF=$(git log -1 --pretty=%B)
    echo "Last commit subject: ${REF}"
else
    REF="$@"
    echo "Manual commit subject: ${REF}"
fi


major=$(cut -f1 -d. .version)
minor=$(cut -f2 -d. .version)
patch=$(cut -f3 -d. .version | cut -f1 -d-)
rm .version
oldversion="${major}.${minor}.${patch}"
case "${REF}" in
    bugfix:*|bug:*|fix:*|automatic-patch:*)
        patch=$((patch+1))
        ;;
    feature:*|feat:*)
        patch=0
        minor=$((minor+1))
        ;;
    major:*)
        patch=0
        minor=0
        major=$((major+1))
        ;;
esac
newversion="${major}.${minor}.${patch}"

# install a more recent Go than apt-get can supply
curl https://dl.google.com/go/go1.12.7.linux-amd64.tar.gz -o go.tar.gz
sudo tar -xvzf go.tar.gz -C /usr/local/
export GOROOT=/usr/local/go
export PATH="$PATH:${GOROOT}/bin"

echo "installing ghr"
go get github.com/tcnksm/ghr
echo "ghr reported $?"

if [ "${oldversion}" == "${newversion}" ]; then
    echo "version not updated: old: ${oldversion} new: ${newversion}"
    exit 0
fi

echo "new version to be created: old: ${oldversion} new: ${newversion}"

find / -name "ghr"
~/go/bin/ghr -soft -t ${GITHUB_TOKEN} -u sbp-cookbooks -r mercury -c ${TRAVIS_COMMIT} -n "Mercury Cookbook v${newversion}" ${newversion}

sed -e "s/version          '1.0.0'/version          '${newversion}'/" -i metadata.rb
cat metadata.rb

echo "${SUPERMARKET_PEM}" | tr _ "\n" > ~/mercury.pem
chmod 600 ~/mercury.pem
knife supermarket share -s https://api.opscode.com/organizations/rdoorn -o /home/travis/build/sbp-cookbooks -k ~/mercury.pem mercury -V -n
