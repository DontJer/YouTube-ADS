current_dir="$(pwd)"

echo 'Creating the necessary folders'
mkdir -p "$current_dir/data" > /dev/null 2>&1
mkdir -p "/usr/local/share/xray" > /dev/null 2>&1
echo 'The necessary folders were created successfully'

echo 'Downloading the list of YouTube ads hosts'
curl -s -o "$current_dir/data/temp-YouTube-ADS.txt" https://raw.githubusercontent.com/kboghdady/youTube_ads_4_pi-hole/master/youtubelist.txt
mv "$current_dir/data/temp-YouTube-ADS.txt" "$current_dir/data/temp-YouTube-ADS"
echo "The download was done successfully"

echo "Removing extra lines..."
sed -E -i '/([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]/!d' "$current_dir/data/temp-YouTube-ADS"
echo "The extra lines were removed successfully"

echo "Checking the difference"
if cmp -s "$current_dir/data/temp-YouTube-ADS" "$current_dir/data/youtube-ads"; then
  rm -rf "$current_dir/data/temp-YouTube-ADS" > /dev/null 2>&1
  echo "Not updated, exiting.."
  exit 1
  else
    mv "$current_dir/data/temp-YouTube-ADS" "$current_dir/data/youtube-ads"
fi


if [ ! -d "domain-list-community" ] || [ -z "$(ls -A domain-list-community)" ]; then

rm -rf domain-list-community > /dev/null 2>&1
git clone https://github.com/v2fly/domain-list-community.git > /dev/null 2>&1
fi

if ! command -v go > /dev/null 2>&1; then
        echo "Go is not installed. Installing..."

        declare -A cpu=( [x86_64]=amd64 [armv7l]=armv6l [aarch64]=arm64)
        cpu_arch=$(uname -m)

        if [[ ! -v cpu["$cpu_arch"] ]]; then
          echo "CPU architecture is not supported. Please install manually."
          exit 1
        fi

        latest_version=$(curl -s https://go.dev/VERSION?m=text)

        response=$(curl -s -L --connect-timeout 5 --max-time 5 --write-out "%{http_code}" -o "$latest_version.linux-${cpu[$cpu_arch]}.tar.gz" "https://go.dev/dl/$latest_version.linux-${cpu[$cpu_arch]}.tar.gz")

if [ $response -eq 200 ]; then
         sudo tar -C /usr/local -xzf "$latest_version.linux-${cpu[$cpu_arch]}.tar.gz"
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        echo 'export GOPATH=$HOME/go' >> ~/.bashrc
        echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
        source ~/.bashrc
		rm -rf "$latest_version.linux-${cpu[$cpu_arch]}.tar.gz" > /dev/null 2>&1
else
  rm -rf "$latest_version.linux-${cpu[$cpu_arch]}.tar.gz" > /dev/null 2>&1
  if [ "$(uname)" == "Linux" ]; then
      if [ -x "$(command -v apt)" ]; then
        sudo apt update -y > /dev/null 2>&1
        sudo apt install golang -y > /dev/null 2>&1
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install golang -y > /dev/null 2>&1
    elif [ -x "$(command -v pacman)" ]; then
        sudo pacman -S --noconfirm go > /dev/null 2>&1
    else
      echo "Unsupported package manager. Please install Go manually."
      exit 1
    fi
  else
    echo "Unsupported operating system. Please install Go manually."
    exit 1
  fi
fi
        if ! command -v go > /dev/null 2>&1; then
            echo "Failed to install Go. Please install manually."
            exit 1
        fi
        echo "Go has been successfully installed."
fi
cd domain-list-community || exit
echo 'Installing project dependencies'
go mod download > /dev/null 2>&1
echo 'Project dependencies were successfully installed'

echo 'Creating ac-youtube-ads.dat...'
go run ./ --datapath="$current_dir/data" --outputname="ac-youtube-ads.dat" --outputdir="/usr/local/share/xray" > /dev/null 2>&1
echo 'ac-youtube-ads.dat successfully created'

echo 'Checking for existence of Crontab...'
if ! crontab -l | grep -q "ac-youtube-ads.sh"; then
  echo 'Adding Crontab...'
{ crontab -l -u root; echo "0 */1 * * * /bin/bash $current_dir/ac-youtube-ads.sh >/dev/null 2>&1"; } | crontab -u root -
  echo 'Crontab added successfully'
fi

echo "Done"
echo 'Add "ext:ac-youtube-ads.dat:youtube-ads" to xray_config.json'
