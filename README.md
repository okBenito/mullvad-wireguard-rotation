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

1. Save your Mullvad account number in a file and update the ACCOUNT_FILE variable. The file should contain only your 16-digit Mullvad account number, without any extra spaces or newlines.

2. Generate the starting wireguard key in your Mullvad account using their wireGuard configuration file generator. Download and use any of their wireguard relays. You only need to do this once, then the script will update it going forward.

# Usage

1. Clone this repository:

```bash
git clone https://github.com/okbenito/mullvad-wireguard-rotation.git
cd mullvad-wireguard-rotation
```

2. Run the script:

```bash
/bin/bash /path/to/rotate.sh
```

The script will:

1. Read your Mullvad account number from the specified file.
2. Generate a new Wireguard private and public key.
3. Submit the new public key to Mullvad.
4. Retrieve a new Wireguard IP and endpoint from Mullvad, selecting only from USA relays.
5. Update your local Wireguard configuration with the new keys and endpoint.
6. Restart the Wireguard service to apply the changes.

## Security Benefits

Regularly rotating your Wireguard keys improves security by:

1. Minimizing Exposure: Regular key rotation reduces the window of opportunity for potential attackers to exploit compromised keys.
2. Enhancing Anonymity: Changing IP addresses and endpoints frequently helps in maintaining anonymity by making it more difficult to track online activities.
3. Compliance: Some security policies and compliance frameworks recommend or require regular key rotations as part of best practices for maintaining secure communications.

## Recommended Usage

To maximize security, it is recommended to run this script on a regular basis. You can automate this process using a cron job to ensure your Wireguard keys are rotated daily. To set up a daily cron job, you can use the following steps:

1. Open the crontab file for editing:

```bash
crontab -e
```

2. Add the following line to schedule the script to run at boot:

```bash
@reboot /bin/bash /path/to/rotate.sh
```

Replace `/path/to/rotate.sh` with the actual path to the `rotate.sh` script.

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
