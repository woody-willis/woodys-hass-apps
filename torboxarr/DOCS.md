# TorBoxarr

Makes [TorBox](https://torbox.app) look like qBittorrent and SABnzbd so Sonarr/Radarr can use it as a download client.

## Options

| Option | Description |
|---|---|
| `torbox_api_token` | Your TorBox API token (required) |
| `qbit_password` | Password you choose for the fake qBittorrent login (required) |
| `sab_api_key` | API key you choose for the fake SABnzbd API (required) |
| `sab_nzb_key` | Optional separate NZB key; defaults to `sab_api_key` |
| `server_base_url` | Optional base URL reported to clients (default `http://localhost:8085`) |
| `data_root` | Where downloads are stored (default `/share/torboxarr`) |
| `log_level` | `DEBUG`, `INFO`, `WARN`, `ERROR` |
| `puid` / `pgid` | UID/GID files are written as. Match Sonarr/Radarr (`0`/`0` = root). The top-level `data_root` folder is chowned to this user |

The SQLite database is stored in the app's private `/data` volume and is included in HA backups.

## Connecting Sonarr / Radarr

- **qBittorrent client:** host = this app's hostname (e.g. `<slug-prefix>-torboxarr`, or the HA IP), port `8085`, username `admin`, password = `qbit_password`.
- **SABnzbd client:** same host/port, API key = `sab_api_key`.

Sonarr/Radarr must see the same completed-download path. Keep `data_root` under `/share` (or `/media`) and mount the same location in those apps.
Categories map to folders under `<data_root>/completed/<category>`.
