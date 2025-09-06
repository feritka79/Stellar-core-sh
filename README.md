# Stellar Core Testnet Setup

This repository contains a **bash script** to quickly set up a **Stellar Core node** on the **Testnet**.

> Script filename: `stellar-core-testnet.sh`


## Features

- Installs dependencies
- Creates a dedicated `stellar` user
- Sets up PostgreSQL database `stellar_testnet`
- Clones and builds Stellar Core from source
- Generates `stellar-core.cfg`
- Configures systemd service for automatic startup
- Adds convenient shell aliases:
  - `core-log` → tail the last 30 lines of Stellar Core log
  - `core-live` → query the node's current info via HTTP


## Prerequisites

- **Hardware Requirements:** Please check the official [Stellar documentation prerequisites](https://developers.stellar.org/docs/validators/admin-guide/prerequisites) for up-to-date hardware and system requirements.
- Linux server (Ubuntu recommended)
- sudo privileges
- Internet access
- Basic terminal familiarity


## Installation

1. **Download the script:**

```bash
wget https://github.com/feritka79/Stellar-core-sh/blob/master/stellar-core-testnet.sh
chmod +x stellar-core-testnet.sh
```

2. **Run the script:**

```bash
./stellar-core-testnet.sh
```

3. **Follow interactive prompts:**

- Base path (default `/home/stellar`)
- PostgreSQL password
- Stellar Core version (default `23.0.1`)
- Node Seed (keep secret)
- Full catchup? (`y`/`n`)
- Shell type (`bash` or `zsh`)

---

## After Installation

### Manage service

```bash
sudo systemctl start stellar-core
sudo systemctl stop stellar-core
sudo systemctl restart stellar-core
sudo systemctl status stellar-core
```

### Check logs

```bash
sudo journalctl -fu stellar-core
```

### Use aliases

```bash
source ~/.bashrc   # for bash
source ~/.zshrc    # for zsh
```

- `core-log` → shows last 30 lines of log
- `core-live` → returns node info

---

## Stellar Core Configuration

- Created automatically in: `<BASE_PATH>/stellar-core-config/stellar-core.cfg`
- Contains:

  - Network: Testnet
  - Full catchup option
  - Node seed
  - PostgreSQL connection
  - Validator information
  - Log and bucket paths
  - Quorum and safety settings

---

## Script Overview: `stellar-core-testnet.sh`

The script performs the following steps:

1. Installs required packages.
2. Creates a `stellar` system user.
3. Sets up data and config directories.
4. Sets up PostgreSQL database and user.
5. Clones, checks out, builds, and installs Stellar Core.
6. Creates `stellar-core.cfg` with testnet validators.
7. Configures and starts systemd service.
8. Adds shell aliases for easy log viewing and info querying.

---

## Full Script

You can find the full script in this repository as:

```
stellar-core-testnet.sh
```

This script is fully interactive and guides you through:

- Selecting base paths
- Setting passwords
- Node seeds
- Choosing full catchup
- Setting shell aliases

---

## Notes

- **Keep your NODE SEED secret!** Never share it publicly.
- The default network passphrase is for the Testnet: `Test SDF Network ; September 2015`.
- This setup is meant for **testing and development** only, not for mainnet production.

---

## License

This repository is open-source. Feel free to use and modify the script for your Stellar testnet experiments.
