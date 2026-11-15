# MeTube

[MeTube](https://github.com/alexta69/metube) is a self-hosted web UI for
[yt-dlp](https://github.com/yt-dlp/yt-dlp). Paste a link from YouTube or
[hundreds of other sites](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md)
and it downloads video, audio, subtitles and thumbnails to your Home Assistant
box. It supports playlists, channels, subscriptions and per-download format
choices.

This app runs the official MeTube image and is available in the Home Assistant
sidebar through ingress.

## Options

| Option | Description |
|---|---|
| `puid` / `pgid` | UID/GID MeTube runs as and writes files with (default `0` = root). The top level of each configured folder is chowned to this user; existing files are left alone |
| `download_dir` | Where downloads are saved (default `/media/metube`). Must be under `/media` or `/share` so Home Assistant can see the files |
| `audio_download_dir` | Optional separate folder for audio-only downloads. Empty uses `download_dir`. Must be under `/media` or `/share`; a relative path is resolved against `download_dir`, and `/downloads/...` is accepted as an alias for `download_dir` |
| `temp_dir` | Optional folder for in-progress downloads. Empty uses `download_dir`. Same path rules as `audio_download_dir` |
| `max_concurrent_downloads` | Downloads that run at once; the rest wait (default `3`) |
| `output_template` | yt-dlp filename template (default `%(title)s.%(ext)s`) |
| `default_theme` | `auto`, `light` or `dark` |
| `log_level` | `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` or `NONE` |
| `ytdl_options` | Optional JSON object of [yt-dlp API options](https://github.com/alexta69/metube/wiki/yt-dlp-options) applied to every download, e.g. `{"writesubtitles": true, "subtitleslangs": ["en"]}` |
| `ytdl_nightly_update_time` | Optional `HH:MM` (24-hour). When set, MeTube upgrades yt-dlp from the nightly channel daily at that time and restarts. Requires `puid`/`pgid` `0` |

The download queue, history, subscriptions and uploaded cookies are stored in
`/data/metube`, which is private to the app and included in Home Assistant
backups.

The resolved download, audio and temp folders are printed in the app log on
every start, so you can confirm the options took effect. Restart the app after
changing options; Home Assistant does not apply them to an already running
container.

## Using it

Open **MeTube** in the sidebar (ingress). Direct access on port `8081` is
available if you assign a host port under the app's **Network** settings; it is
not exposed by default because MeTube has no built-in authentication.

Downloads are saved to `download_dir`; the file links in the Completed section
work through ingress as well.

## Notes

- The image is pinned to MeTube release `2026.11.14`. Update the version in
  `config.yaml` and the `Dockerfile` to move to a newer release.
- MeTube itself is an unofficial project and is not affiliated with YouTube.
  Respect the terms of service of the sites you download from.
- For format selection, subscriptions, cookies and yt-dlp recipes see the
  [MeTube wiki](https://github.com/alexta69/metube/wiki).
