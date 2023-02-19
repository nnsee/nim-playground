#!/bin/bash

location=$(dirname $0)
processes="$(ps -e)"

if [ "$(echo "$processes" | grep updateimages.sh | wc -l)" -gt 1 ] ; then
  echo "Detected running script, quitting"
  exit 0
fi

missing=$(uniq -u <(sort <(cat "$location/ignored" <(git ls-remote --tags https://github.com/nim-lang/nim | sed -n 's/.*refs\/tags\/\(.*\)^{}/\1/p') <(docker images | sed -n 's/virtual_machine *\(v[^ ]*\).*/\1/p'))))
latest=$(git ls-remote --tags https://github.com/nim-lang/nim | sed -n 's/.*refs\/tags\/\(.*\)^{}/\1/p' | sed 's/v/0./' | sort -t. -n -k1,1 -k2,2 -k3,3 -k4,4 | sed 's/0./v/' | tail -n1)

while read -r line; do
  if [ ! -z "$line" ]; then
    echo $line > "$location/curtag"
    cat "$location/curtag"
    if [ "$line" == "$latest" ]; then
      docker build --no-cache -t "virtual_machine:$line" "$location"
    else
      docker build --no-cache -t "virtual_machine:$line" -f "$location/Dockerfile_nopackages" "$location"
    fi
    docker system prune -f --volumes
  fi
done <<< $missing

rm "$location/curtag"

docker tag virtual_machine:$(docker images | sed -n 's/virtual_machine *\(v[^ ]*\).*/\1/p' | sort --version-sort | tail -n1) virtual_machine:latest
docker system prune -f --volumes
docker container prune -f
