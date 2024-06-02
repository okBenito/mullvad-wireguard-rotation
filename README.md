# Mullvad Wireguard Key Rotation Script

This script automates the rotation of Wireguard keys for a Mullvad VPN account. It generates a new private and public key, submits the new key to Mullvad, retrieves a new Wireguard IP and endpoint, and updates the local Wireguard configuration. This version specifically selects USA relays for the Wireguard endpoint, however `rotate-all.sh` will include all wireguard relays.

## Prerequisites

Ensure you have the following tools installed on your system:

- `curl`
- `wg` (Wireguard)
- `jq`
- `systemctl`

You can install them using the following commands:

```bash
sudo apt-get update
sudo apt-get install -y curl wireguard jq
```

# Setup

1. Save your Mullvad account number in a file and update the ACCOUNT_FILE variable.

2. The file should contain only your 16-digit Mullvad account number, without any extra spaces or newlines.

# Usage

1. Clone this repository:

```bash
git clone https://github.com/okbenito/mullvad-wireguard-rotation.git
cd mullvad-wireguard-rotation
```

2. Make the script executable:

```bash
chmod +x rotate.sh
```

3. Run the script:

```bash
./rotate.sh
```

The script will:

1. Read your Mullvad account number from the specified file.
2. Generate a new Wireguard private and public key.
3. Submit the new public key to Mullvad.
4. Retrieve a new Wireguard IP and endpoint from Mullvad, selecting only from USA relays.
5. Update your local Wireguard configuration with the new keys and endpoint.
6. Restart the Wireguard service to apply the changes.

## Troubleshooting

- Ensure the account number file is correctly formatted and located at location specified
- Check that all required commands (curl, wg, jq, systemctl) are installed and available in your PATH.
- Make sure you have the necessary permissions to read the account number file and write to the Wireguard configuration file.

## License

This project is released into the public domain under the terms of the Unlicense. For more information, see the [LICENSE](LICENSE) file or visit <http://unlicense.org>.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

## Disclaimer

This script is provided as-is without any warranties. Use at your own risk.
