# DuckDNS updater and installers

Updates public IPv4 using DuckDNS automatic detection. Uses HTTPS, five-minute intervals, and separate access-restricted config files. Requires a DuckDNS account, token, and at least one pre-created DuckDNS subdomain. Supports comma-separated subdomains.

## Windows (PowerShell 5.1+)

Open PowerShell **as Administrator** in this folder:

```powershell
.\Install-DuckDNS.ps1 -Domains 'myhome,office'
```

Enter the token when prompted. This installs a Scheduled Task named `DuckDNS Updater` running as SYSTEM. Files are stored in `C:\ProgramData\DuckDNS` (config restricted to SYSTEM/Administrators). Check:

```powershell
Get-ScheduledTask -TaskName 'DuckDNS Updater'
Get-Content 'C:\ProgramData\DuckDNS\duckdns.log' -Tail 20
```

Manual update (elevated): `& 'C:\ProgramData\DuckDNS\Update-DuckDNS.ps1'`

Uninstall (elevated): `Unregister-ScheduledTask -TaskName 'DuckDNS Updater' -Confirm:$false; Remove-Item 'C:\ProgramData\DuckDNS' -Recurse -Force`

## Linux (systemd)

```bash
chmod +x install-duckdns.sh duckdns-update.sh
sudo ./install-duckdns.sh myhome,office
```

Enter token when prompted. The updater is installed in `/usr/local/sbin/duckdns-update`, config at `/etc/duckdns/duckdns.conf` (root-only), and a systemd timer runs every five minutes.

```bash
sudo systemctl status duckdns.timer
sudo journalctl -u duckdns.service -n 20 --no-pager
sudo systemctl start duckdns.service
```

Uninstall:

```bash
sudo systemctl disable --now duckdns.timer; sudo rm -f /etc/systemd/system/duckdns.{timer,service} /usr/local/sbin/duckdns-update; sudo rm -rf /etc/duckdns; sudo systemctl daemon-reload
```

## Notes
- DNS records may take time to reflect updates due to caching.
- This updates **IPv4**, not IPv6.
- For Linux, requires `curl` and `systemd`. Installer deliberately does not modify package repositories.
- The DuckDNS token is a credential. Do not include it in scripts, commit it to Git, or post it in logs.
- An IP change behind CGNAT does not make your host reachable from the public internet by itself; inbound connectivity still requires appropriate network access and firewall/router settings.
