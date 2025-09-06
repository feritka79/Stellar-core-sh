#!/bin/bash
set -e
set -o pipefail

echo "=== Stellar Core Testnet Setup (Steps 1-5) ==="

#1 Install packages
echo "[1/5] Installing dependencies..."
sudo apt update
sudo apt install -y build-essential cmake pkg-config libssl-dev \
    libpq-dev libcurl4-openssl-dev zsh curl git postgresql postgresql-contrib \
    autoconf automake libtool

#2 Stellar user
echo "[2/5] Creating stellar user..."
sudo useradd -m -s /bin/bash stellar || true

#3 Data paths
read -p "Enter base path for Stellar Core data (default /home/stellar): " BASE_PATH
BASE_PATH=${BASE_PATH:-/home/stellar}

echo "[3/5] Creating directories..."
sudo mkdir -p "$BASE_PATH/stellar-core-data/buckets"
sudo mkdir -p "$BASE_PATH/stellar-core-config"
sudo chown -R stellar:stellar "$BASE_PATH/stellar-core-data"
sudo chown -R stellar:stellar "$BASE_PATH/stellar-core-config"

#4 Database
echo "[4/5] Setting up PostgreSQL database..."
while true; do
    read -sp "Enter Postgres password for stellar_testnet DB: " DB_PASS
    echo
    read -sp "Confirm password: " DB_PASS2
    echo
    [ "$DB_PASS" = "$DB_PASS2" ] && break || echo "Passwords do not match. Try again."
done

if ! systemctl is-active --quiet postgresql; then
    echo "Starting PostgreSQL..."
    sudo systemctl start postgresql
fi

# Secure creation with IF NOT EXISTS
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='stellar_testnet'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE stellar_testnet;"

sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='stellar'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER stellar WITH ENCRYPTED PASSWORD '$DB_PASS';"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE stellar_testnet TO stellar;"

#5 Install Stellar Core
read -p "Enter Stellar Core version to install (default 23.0.1): " CORE_VER
CORE_VER=${CORE_VER:-23.0.1}

echo "[5/5] Installing Stellar Core..."
cd "$BASE_PATH"
if [ ! -d "stellar-core" ]; then
    sudo -u stellar git clone https://github.com/stellar/stellar-core.git
else
    echo "stellar-core directory exists. Pulling latest..."
    cd stellar-core
    sudo -u stellar git fetch
    sudo -u stellar git reset --hard origin/main
    cd ..
fi

cd "$BASE_PATH/stellar-core"
sudo -u stellar git checkout "$CORE_VER"
./autogen.sh
./configure
make -j$(nproc)
sudo make install

echo "✅ Steps 1-5 completed successfully!"
echo "Next: configure stellar-core.cfg and systemd service (Steps 6-7)."

#6 Config stellar-core.cfg
while true; do
    read -sp "Enter NODE SEED (keep secret): " NODE_SEED
    echo
    read -sp "Confirm NODE SEED: " NODE_SEED2
    echo
    [ "$NODE_SEED" = "$NODE_SEED2" ] && break || echo "Node seeds do not match. Try again."
done

read -p "Full catchup? (y/n, default y): " FULL_CATCHUP
FULL_CATCHUP=${FULL_CATCHUP:-y}
CATCHUP_COMPLETE=true
[ "$FULL_CATCHUP" != "y" ] && CATCHUP_COMPLETE=false

echo "[6/7] Creating configuration..."
cat <<EOL | sudo tee "$BASE_PATH/stellar-core-config/stellar-core.cfg"
NETWORK_PASSPHRASE="Test SDF Network ; September 2015"
PEER_PORT=11625
HTTP_PORT=11626
PUBLIC_HTTP_PORT=true

DATABASE="postgresql://stellar:$DB_PASS@127.0.0.1/stellar_testnet"

LOG_FILE_PATH="$BASE_PATH/stellar-core-data/stellar-core.log"
BUCKET_DIR_PATH="$BASE_PATH/stellar-core-data/buckets"

CATCHUP_COMPLETE=$CATCHUP_COMPLETE
UNSAFE_QUORUM=true
FAILURE_SAFETY=1

NODE_IS_VALIDATOR=true
NODE_SEED="$NODE_SEED"
NODE_HOME_DOMAIN="testnet.stellar.org"

[[HOME_DOMAINS]]
HOME_DOMAIN="testnet.stellar.org"
QUALITY="HIGH"

# Testnet validators
[[VALIDATORS]]
NAME="sdf_testnet_1"
HOME_DOMAIN="testnet.stellar.org"
PUBLIC_KEY="GDKXE2OZMJIPOSLNA6N6F2BVCI3O777I2OOC4BV7VOYUEHYX7RTRYA7Y"
ADDRESS="core-testnet1.stellar.org"
HISTORY="curl -sf https://history.stellar.org/prd/core-testnet/core_testnet_001/{0} -o {1}"

[[VALIDATORS]]
NAME="sdf_testnet_2"
HOME_DOMAIN="testnet.stellar.org"
PUBLIC_KEY="GCUCJTIYXSOXKBSNFGNFWW5MUQ54HKRPGJUTQFJ5RQXZXNOLNXYDHRAP"
ADDRESS="core-testnet2.stellar.org"
HISTORY="curl -sf https://history.stellar.org/prd/core-testnet/core_testnet_002/{0} -o {1}"

[[VALIDATORS]]
NAME="sdf_testnet_3"
HOME_DOMAIN="testnet.stellar.org"
PUBLIC_KEY="GC2V2EFSXN6SQTWVYA5EPJPBWWIMSD2XQNKUOHGEKB535AQE2I6IXV2Z"
ADDRESS="core-testnet3.stellar.org"
HISTORY="curl -sf https://history.stellar.org/prd/core-testnet/core_testnet_003/{0} -o {1}"
EOL

sudo chown stellar:stellar "$BASE_PATH/stellar-core-config/stellar-core.cfg"

#7 Config systemd
echo "[7/7] Creating systemd service..."
cat <<EOL | sudo tee /etc/systemd/system/stellar-core.service
[Unit]
Description=Stellar Core (Testnet)
After=network.target postgresql.service
Wants=postgresql.service

[Service]
User=stellar
Group=stellar
ExecStart=/usr/bin/stellar-core --conf $BASE_PATH/stellar-core-config/stellar-core.cfg run
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
LimitNOFILE=65535
Environment="METADATA_OUTPUT_STREAM=$BASE_PATH/stellar-core-data/stellar-core-meta.pipe"
Environment="NODE_IS_VALIDATOR=true"

[Install]
WantedBy=multi-user.target
EOL

echo "Reloading systemd..."
sudo systemctl daemon-reload
sudo systemctl enable stellar-core
sudo systemctl start stellar-core

echo "✅ Stellar Core Testnet setup complete!"
echo "You can check logs live with: sudo journalctl -fu stellar-core"

#8 Add aliases for convenience
echo "[8/8] Adding Stellar Core aliases..."

# Detect shell
read -p "Which shell do you use? (bash/zsh) [default bash]: " USER_SHELL
USER_SHELL=${USER_SHELL:-bash}

if [[ "$USER_SHELL" == "zsh" ]]; then
    PROFILE_FILE="$HOME/.zshrc"
elif [[ "$USER_SHELL" == "bash" ]]; then
    PROFILE_FILE="$HOME/.bashrc"
else
    echo "❌ Unsupported shell: $USER_SHELL"
    exit 1
fi

# Aliases content
CORE_ALIASES="
alias core-log='tail -n 30 -f $BASE_PATH/stellar-core-data/stellar-core.log'
alias core-live=\"sudo -u stellar stellar-core --conf $BASE_PATH/stellar-core-config/stellar-core.cfg http-command 'info'\"
"

# Check if already exists
if grep -q "alias core-log" "$PROFILE_FILE"; then
    echo "Aliases already exist in $PROFILE_FILE, skipping..."
else
    echo "$CORE_ALIASES" >> "$PROFILE_FILE"
    echo "✅ Aliases added to $PROFILE_FILE"
fi

echo "You can apply changes with: source $PROFILE_FILE"
