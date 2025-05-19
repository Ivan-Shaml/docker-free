#!/bin/bash
#
#  Generates server-side and client-side certificates for Docker Engine.
#  This can be used to secure the docker daemon with mTLS.
#
#  Requires OpenSSL v3 or later.
#  For example, this means the script will not work on Ubuntu 20.04 as it is too old!
#
#
#  sudo access is required as the script needs to write to '/etc/docker'
#



# CONSTANTS:
# ------------
# The number of days the certificates should be valid.
#
# 18250 is roughly 50 years
#
validity_days=18250

# Location where server-side TLS certs for the docker daemon is placed
docker_server_certs_folder=/etc/docker/certs




# FUNCTION
# Convert a Windows path into a WSL2 equivalent.
# For example
#    C:\Users\john\.docker  --> /mnt/c/Users/john/.docker
#
wslpath() {
  local windows_path="$1"
  if [[ "$windows_path" =~ ^([A-Za-z]):\\(.*) ]]; then
    local drive_letter="${BASH_REMATCH[1]}"
    local path_rest="${BASH_REMATCH[2]}"
    local wsl_path="/mnt/${drive_letter,,}/${path_rest//\\//}"
    echo "$wsl_path"
  else
    echo "Error: $windows_path" # Return the original path if it's not a Windows path
  fi
}

# FUNCTION
# Gets the value of a Windows OS environment variable
#
win_env_var() {
    local winvar=$(cmd.exe /D /C echo "%${1}%" 2>/dev/null)
    echo "${winvar//[$'\r\n']}"
}






# Sanity check 1
if [ ! -n "${WSL_DISTRO_NAME}" ]; then
  echo "Error: Expects to be executing in WSL2 environment"
  exit 1
fi

# Sanity check 2
if [[ "${WSL_DISTRO_NAME}" != Ubuntu* ]]; then
  echo "Error: WSL distro is '${WSL_DISTRO_NAME}'. This script has only been tested with WSL2 + Ubuntu"
  exit 1
fi




sudo mkdir -p $docker_server_certs_folder



# ---------------------------------------
#  CA ROOT
# ---------------------------------------


# Generate the Root Key:
echo "Generating CA's root key"
openssl genpkey -algorithm RSA -out root.key 2>/dev/null

csrtempfile=$(mktemp)
cat << EOF > "$csrtempfile"
[ req ]
prompt             = no
default_bits       = 4096
distinguished_name = req_distinguished_name
req_extensions     = req_ext

[ req_distinguished_name ]
commonName         = Docker Engine - (ROOT)

[ req_ext ]
keyUsage           = critical,keyCertSign,cRLSign
basicConstraints   = critical,CA:TRUE
EOF


# Generate the Root Certificate:
echo "Generating CA certificate"
openssl req -new -x509 -config "$csrtempfile" -key root.key -out root.crt -days $validity_days -extensions req_ext
rm -r -f "$csrtempfile"



# ---------------------------------------
#  LEAF - Server-side cert
# ---------------------------------------

# Generate the Leaf Key:
echo ""
echo "Generating server-side key"
openssl genpkey -algorithm RSA -out leaf.key 2>/dev/null

# Generate the Leaf CSR:
csrtempfile=$(mktemp)
cat << EOF > "$csrtempfile"
[ req ]
prompt             = no
default_bits       = 4096
distinguished_name = req_distinguished_name
req_extensions     = req_ext

[ req_distinguished_name ]
commonName         = Docker Engine - Server (LEAF)

[ req_ext ]
subjectAltName     = @alt_names
keyUsage           = critical,digitalSignature
extendedKeyUsage   = serverAuth
basicConstraints   = critical,CA:FALSE

[alt_names]
DNS.1   = localhost
IP.1    = 127.0.0.1
EOF


echo "Generating server-side certificate"
openssl req -new -key leaf.key -out leaf.csr  -config "$csrtempfile" -extensions req_ext
rm -r -f "$csrtempfile"


# Sign the Leaf Certificate with the Root Certificate:
openssl x509 -req -in leaf.csr -CA root.crt -CAkey root.key -CAcreateserial -out leaf.crt -days $validity_days  -copy_extensions=copyall 2>/dev/null

rm leaf.csr   # no longer needed


# Rename to the file names expected by docker
sudo cp root.crt $docker_server_certs_folder/ca.pem
sudo mv leaf.crt $docker_server_certs_folder/cert.pem
sudo mv leaf.key $docker_server_certs_folder/key.pem
echo "Certificate files for docker engine now exist in $docker_server_certs_folder"








# ---------------------------------------
#  LEAF - Client-side cert
# ---------------------------------------

# Generate the Leaf Key:
echo ""
echo "Generating client-side key"
openssl genpkey -algorithm RSA -out leaf.key 2>/dev/null

# Generate the Leaf CSR:
csrtempfile=$(mktemp)
cat << EOF > "$csrtempfile"
[ req ]
prompt             = no
default_bits       = 4096
distinguished_name = req_distinguished_name
req_extensions     = req_ext

[ req_distinguished_name ]
commonName         = Docker Engine - Client (LEAF)

[ req_ext ]
keyUsage           = critical,digitalSignature
extendedKeyUsage   = clientAuth
basicConstraints   = critical,CA:FALSE
EOF


openssl req -new -key leaf.key -out leaf.csr  -config "$csrtempfile" -extensions req_ext
rm -r -f "$csrtempfile"


# Sign the Leaf Certificate with the Root Certificate:
echo "Generating client-side certificate"
openssl x509 -req -in leaf.csr -CA root.crt -CAkey root.key -CAcreateserial -out leaf.crt -days $validity_days  -copy_extensions=copyall 2>/dev/null

rm leaf.csr   # no longer needed







rm root.key   # Throw away the ROOT key!


# Rename to the file names expected by docker CLI
mkdir -p ~/.docker

mv root.crt ~/.docker/ca.pem
mv leaf.crt ~/.docker/cert.pem
mv leaf.key ~/.docker/key.pem
echo "Certificate files for docker CLI now exist in $HOME/.docker"


# Find Windows home dir
win_userprofile=$(win_env_var USERPROFILE)
win_userprofile_wsl=$(wslpath "$win_userprofile")

mkdir -p "${win_userprofile_wsl}/.docker"

# Copy from Linux home folder to Windows home folder
cp ~/.docker/ca.pem   "${win_userprofile_wsl}/.docker/ca.pem"
cp ~/.docker/cert.pem "${win_userprofile_wsl}/.docker/cert.pem"
cp ~/.docker/key.pem  "${win_userprofile_wsl}/.docker/key.pem"
echo "Certificate files for docker CLI now exist in ${win_userprofile}\\.docker"


echo ""
echo "Done!"

echo ""
echo "Set the following environment variables in Windows OS":
echo "  DOCKER_HOST=tcp://localhost:2376"
echo "  DOCKER_TLS_VERIFY=1"
echo "  DOCKER_CERT_PATH=%USERPROFILE%\.docker"
echo ""
echo ""
