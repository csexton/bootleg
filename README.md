# Bootleg

A command-line utility for downloading, archiving, and publishing videos across social media platforms.

## About

Bootleg keeps a local archive of your videos and makes it easy to distribute them across multiple platforms without relying on any one service.

Download once. Archive forever. Publish anywhere.

Don't Panic.

## Installation

Requires Ruby 3.0+.

```bash
git clone https://github.com/csexton/bootleg.git && cd bootleg
bin/setup                 # bundle install
bundle exec exe/bootleg --help
```

Or build and install the gem locally:

```bash
bundle exec rake install
bootleg --help
```

## Usage

Commands are grouped by platform:

```
bootleg PLATFORM COMMAND [options]
```

| Platform  | Command               | Description                                         |
|-----------|-----------------------|-----------------------------------------------------|
| `tiktok`  | `download`            | Download videos and photo posts with metadata       |
| `tiktok`  | `list`                | Print the video URLs on a profile                   |
| `tiktok`  | `index`               | List the posts already downloaded to a directory    |
| `youtube` | `auth`                | Log in to YouTube                                   |
| `youtube` | `schedule`            | Build an upload batch from downloaded posts         |
| `youtube` | `upload`              | Upload and schedule a batch                         |
| `youtube` | `update-descriptions` | Push edited descriptions to already-uploaded videos |
| `youtube` | `shorts`              | List the titles of a channel's newest Shorts        |

Run `bootleg PLATFORM --help` for each platform's options. More platforms
(Instagram and others) will follow the same shape.

## TikTok

Downloads TikTok videos and photos without watermarks, along with a metadata
sidecar for each post.

```bash
# Download a video to the current directory
bootleg tiktok download https://www.tiktok.com/@someuser/video/1234567890

# Specify an output directory
bootleg tiktok download --output-dir ~/Videos/tiktok https://www.tiktok.com/@someuser/video/1234567890

# Save sidecar as JSON instead of plain text
bootleg tiktok download --json https://www.tiktok.com/@someuser/video/1234567890

# Download multiple URLs
bootleg tiktok download URL1 URL2 URL3

# List video URLs for a profile (URLs to stdout, status to stderr)
bootleg tiktok list https://www.tiktok.com/@someuser

# Fetch more pages of a profile
bootleg tiktok list --pages 3 https://www.tiktok.com/@someuser

# Archive a whole profile
bootleg tiktok list --pages 10 https://www.tiktok.com/@someuser | xargs bootleg tiktok download

# What's already downloaded: "date | video id | caption", newest first
bootleg tiktok index ~/Videos/tiktok
```

The output directory is created automatically if it doesn't exist.

### Output

Files are named from up to four components, each toggleable:

```
{username}-{YYYY-MM-DD}-{description-slug}.mp4
{username}-{YYYY-MM-DD}-{description-slug}.txt   # or .json with --json
```

Example: `someuser-2025-04-07-pov-you-didnt-ask-for-this-content.mp4`

The description slug is taken from the first sentence of the caption if it's 5–8
words, otherwise the first 8 words. Punctuation is stripped and spaces become
dashes. If two posts would get the same name, the post ID is appended rather than
overwriting the other post's files.

Photo posts save each image (`-01.jpg`, `-02.jpg`, ...) plus a single metadata
sidecar for the set.

| Flag | Default | Description |
|------|---------|-------------|
| `--[no-]username` | on | Include the author's username |
| `--[no-]date` | on | Include the post date |
| `--[no-]slug` | on | Include a slug from the description |
| `--[no-]id` | off | Include the numeric video ID |

### Sidecar format

The `.txt` sidecar contains:

```
Title:       POV you didn't ask for this content
Author:      Some User (@someuser)
Date:        2025-04-07
Video ID:    1234567890
Source URL:  https://www.tiktok.com/@someuser/video/1234567890
Audio:       original sound - another creator
Audio URL:   https://www.tiktok.com/music/original-sound-7530081457067920142
```

The `Audio` lines name the sound the post uses, so it can be credited. An
"original sound" under the poster's own name is marked `(own audio)`. Posts with
no sound info omit them.

With `--json`:

```json
{
  "title": "POV you didn't ask for this content",
  "author": { "name": "Some User", "username": "someuser" },
  "date": "2025-04-07",
  "video_id": "1234567890",
  "source_url": "https://www.tiktok.com/@someuser/video/1234567890",
  "audio": {
    "title": "original sound",
    "artist": "another creator",
    "original": true,
    "own": false,
    "id": "7530081457067920142",
    "url": "https://www.tiktok.com/music/original-sound-7530081457067920142"
  }
}
```

## YouTube

Uploads videos to YouTube and schedules them to publish at set times, through
the YouTube Data API. Built for cross-posting downloaded TikToks as Shorts, but
any schedule of videos works.

### Setup

1. In [Google Cloud Console](https://console.cloud.google.com/), create a
   project and enable **YouTube Data API v3**.
2. Under OAuth consent screen, set the audience to **External** and add your
   Google account as a test user. ("Internal" only works for Workspace
   accounts in the same organization.)
3. Create an OAuth client ID of type **Desktop app**, download its JSON, and
   save it as `~/.config/bootleg/youtube/client_secrets.json` (or point
   `youtube.client_secrets` at it).
4. Log in with the account that owns the channel:

   ```bash
   bootleg youtube auth
   ```

   The token is saved to `~/.config/bootleg/youtube/token.json`. While the
   OAuth app is in *Testing* mode Google expires the login after 7 days; when
   commands say the login expired, run `bootleg youtube auth` again.

### A batch

A batch is a directory holding a `schedule.csv` and a `videos/` folder. After
uploading, it also holds `uploads.json` (which rows are uploaded, as which
video) and `upload.log`. Keep each batch in its own directory.

**1. Pick the posts.** Write a picks file listing downloaded posts in the order
to publish, with the YouTube title for each:

```
# path to the download (any extension, or none) | YouTube title
~/Videos/tiktok/someuser-2026-11-07-inlay-dovetails-pt-1-this-is-the-part | Inlay Dovetails Pt. 1
~/Videos/tiktok/someuser-2026-11-08-inlay-dovetails-pt-2-cleaning-up      | Inlay Dovetails Pt. 2
```

`bootleg tiktok index DIR` and `bootleg youtube shorts @handle` help find what's
on TikTok but not yet on YouTube.

**2. Build the schedule**, one video per day starting on `--start`:

```bash
bootleg youtube schedule picks.txt --start 2026-12-01 --time 19:00 --dir batches/2026-12
```

This copies each video into `batches/2026-12/videos/` and writes
`schedule.csv`. Each row gets the full caption as the description and the
caption's hashtags (or `default_tags`) plus `shorts` as tags, and is private,
scheduled, and not made for kids. If the sidecar names someone else's sound, a
credit line is added to the end of the description:

```
Original sound by Steven K. (TikTok)
"Song Name" by Some Band (TikTok)
```

Your own sounds get no credit line. Sidecars downloaded before audio was
recorded have no `Audio:` line, so check those by hand. Review and edit the CSV
before uploading.

**3. Upload:**

```bash
bootleg youtube upload batches/2026-12 --dry-run   # check every row, upload nothing
bootleg youtube upload batches/2026-12
```

Videos already in `uploads.json` are skipped, so re-running is safe. Uploads
are spaced out (`--delay`, default 45s). The API allows only a few uploads per
day; if the quota runs out the batch stops, and you re-run it after the quota
resets at midnight Pacific. Every video must be uploaded before its publish
time.

**4. Fixing descriptions later.** Edit `schedule.csv`, then:

```bash
bootleg youtube update-descriptions batches/2026-12 --dry-run
bootleg youtube update-descriptions batches/2026-12
```

Only the description changes; title, tags and schedule are left alone.

### Schedule format

`schedule.csv` uses the same columns as
[youtube-shorts-scheduler](https://github.com/padderzahoor/youtube-shorts-scheduler),
so its schedule files work as they are (pass `--video-dir` if the videos aren't
in a `videos/` folder beside the CSV):

```csv
video_filename,title,description,tags,publish_date,publish_time,privacy_status,category_id,made_for_kids
01-inlay.mp4,Inlay Dovetails Pt. 1,"Caption #woodworking","woodworking,shorts",2026-12-01,19:00,private,26,false
```

`publish_date`/`publish_time` are in `youtube.timezone` (default: the system's
zone). Scheduled videos must be `private`; YouTube makes them public at the
publish time. Leave `publish_date` empty to upload without scheduling.

### Notes

- Right after uploading, a Short can show under "Videos" while it processes.
  It moves to Shorts once processing finishes (vertical and 3 minutes or less).
- Unaudited API projects can have uploads locked to private. If Studio shows a
  lock notice, set the schedule by hand in Studio.

## Configuration

Defaults live in a YAML file, with one top-level key per platform. The file in
the current directory takes precedence over the one in your home directory, and
command-line flags override both.

- `~/.bootleg.yml` — user-wide defaults
- `./.bootleg.yml` — per-project override

```yaml
tiktok:
  output_dir: ~/Videos/tiktok
  json_sidecar: true
  pages: 1

  # Filename components (shown with defaults)
  filename_username: true
  filename_date: true
  filename_slug: true
  filename_id: false

youtube:
  timezone: America/New_York        # default: the system's zone
  publish_time: "19:00"             # default for `schedule --time`
  category_id: "26"                 # Howto & Style (default 22, People & Blogs)
  default_tags: [woodworking, handtools]  # used when a caption has no hashtags
  delay: 45                         # seconds between uploads
  handle: "@someuser"               # default channel for `youtube shorts`
  # client_secrets: ~/.config/bootleg/youtube/client_secrets.json
  # token_path: ~/.config/bootleg/youtube/token.json
```

## Development

```bash
bin/setup            # install dependencies
bundle exec rake     # run the specs
bin/console          # IRB with bootleg loaded
```

Specs never touch the network; the HTTP layer is always stubbed.

## Credits

The TikTok downloader began as [archivetok](https://github.com/csexton/archivetok),
a Ruby port of [tiktok-downloader-console](https://github.com/RehanDias/tiktok-downloader-console)
by [rehandiazz](https://github.com/RehanDias), which provides the original Node.js
implementation and the fallback API endpoint.

The YouTube uploader is a Ruby port of
[youtube-shorts-scheduler](https://github.com/padderzahoor/youtube-shorts-scheduler)
by [Padder Zahoor](https://github.com/padderzahoor), including its CSV schedule
format.

## License

MIT. See [LICENSE](LICENSE).
