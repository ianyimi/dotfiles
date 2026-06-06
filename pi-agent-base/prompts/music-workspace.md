# Music Downloader Workspace Setup

You are setting up the `~/Documents/Music/` workspace — a DJ music library managed via Spotify playlist downloads using `spotdl`.

## Workspace Purpose

- **Download** Spotify playlists into genre-organized folders
- **Track** downloaded songs to avoid re-downloading
- **Maintain** a flat `All/` folder with symlinks for DJ software (djay Pro)
- **Reuse** the user's personal Spotify API credentials stored in this workspace

## Directory Structure

```
~/Documents/Music/
├── .pi/
│   ├── AGENTS.md              ← You are here
│   ├── agent-docs/
│   │   ├── product/
│   │   │   └── tmux-workspace.md
│   │   ├── standards/
│   │   │   └── music-organization.md
│   │   └── implementation/
│   │       └── download-log.md
│   ├── scripts/
│   │   └── download.py        ← Main downloader
│   ├── config.json            ← Spotify creds + paths
│   └── downloaded.json        ← Tracking DB (artist - title → path)
├── Afrobeats/
├── Amapiano/
├── "Hip Hop : Rap"/
├── Future/
├── Kaytra/
├── Oldies/
├── "King of Pop"/
└── All/                       ← Symlinks to every genre folder
```

## Spotify Credentials

Stored in `~/Documents/Music/.pi/config.json`:
```json
{
  "client_id": "b1a3ec799e054f39a75847704a716576",
  "client_secret": "2be7df8723bd4705b80839cfd61385e9",
  "base_path": "~/Documents/Music",
  "all_folder": "All",
  "genre_map": {
    "PIANO PIANOOO": "Amapiano",
    "bomboclat": "Afrobeats",
    "Rap Mix": "Hip Hop : Rap"
  }
}
```

## When the User Says "Download this playlist"

1. Ask for (or extract from context):
   - Spotify playlist URL
   - Genre folder (or infer from the genre_map above)
   - Start track index (if they only want tracks from a certain position)

2. Append the playlist to `~/Documents/Music/.pi/config.json` under `playlists`:
   ```json
   {
     "url": "https://open.spotify.com/playlist/...",
     "start": 1,
     "genre": "Amapiano"
   }
   ```

3. Run the download script:
   ```bash
   cd ~/Documents/Music/.pi
   ~/Downloads/spotdl-venv/bin/python scripts/download.py
   ```

4. The script will:
   - Fetch the playlist via Spotify API (using the stored creds)
   - Skip already-downloaded tracks (checks `downloaded.json`)
   - Download each new track with `spotdl download <url>`
   - Save to the genre folder
   - Create a symlink in `All/`
   - Record the download in `downloaded.json`

## Tmux Session

The tmuxinator config is at `~/.config/tmuxinator/music.yml`. Start it with:
```bash
tmuxinator start zaye-dj
```

Panes:
- `zaye-dj:0.0` — download script runner
- `zaye-dj:0.1` — live log tail (`tail -f ~/Documents/Music/.pi/download.log`)
- `zaye-dj:1.0` — shell in `~/Documents/Music`
- `zaye-dj:1.1` — spare shell

Check pane output with:
```bash
tmux capture-pane -t zaye-dj:0.0 -p -S -50
tmux capture-pane -t zaye-dj:0.1 -p -S -50
```

## Agent Rules

- **Never run `rm -rf`** on `~/Documents/Music/` or any subfolder
- **Always check `downloaded.json`** before downloading to avoid duplicates
- **Always create symlinks** in `All/` after downloading to a genre folder
- **Flush logs immediately** — use `PYTHONUNBUFFERED=1` and write to `download.log`
- **Use `subprocess.run(..., timeout=120)`** so a stuck `spotdl` download doesn't hang forever
