# YouTube

Uploads videos to YouTube and schedules them to publish at set times, through
the YouTube Data API. Built for cross-posting downloaded TikToks as Shorts, but
any schedule of videos works.

## Setup

Uploading goes through your own Google Cloud project, so there's a one-time
setup.

### Google Cloud project

1. In [Google Cloud Console](https://console.cloud.google.com/), create a
   project (or pick an existing one).
2. Under **APIs & Services → Library**, enable **YouTube Data API v3**.
3. Under **APIs & Services → OAuth consent screen**:
   - Set the audience to **External**. ("Internal" only works for Workspace
     accounts in the same organization. Personal accounts get "Access blocked:
     can only be used within its organization".)
   - Leave the publishing status as **Testing**, and add the Google account
     that owns the channel as a **test user**.
4. Under **APIs & Services → Credentials**, create an **OAuth client ID** of
   type **Desktop app** and download its JSON.

### Bootleg

Save the downloaded JSON where Bootleg looks for it (or point
`youtube.client_secrets` at it):

```bash
mkdir -p ~/.config/bootleg/youtube
mv ~/Downloads/client_secret_*.json ~/.config/bootleg/youtube/client_secrets.json
```

Then log in with the account that owns the channel:

```bash
bootleg youtube auth            # opens a browser
bootleg youtube auth --no-browser  # just print the URL
```

The token is saved to `~/.config/bootleg/youtube/token.json`. It asks for two
scopes: upload, and `youtube.force-ssl` to edit uploaded videos' descriptions.

While the app is in Testing mode, Google expires the login after **7 days**.
When a command says the login expired, run `bootleg youtube auth` again.

## Uploading a batch

A batch is a directory holding a `schedule.csv` and a `videos/` folder. After
uploading, it also holds `uploads.json` (which rows are uploaded, as which
video) and `upload.log`. Keep each batch in its own directory.

### 1. Pick the posts

Write a picks file listing downloaded posts in the order to publish, with the
YouTube title for each:

```
# path to the download (any extension, or none) | YouTube title
~/Videos/tiktok/someuser-2026-11-07-inlay-dovetails-pt-1-this-is-the-part | Inlay Dovetails Pt. 1
~/Videos/tiktok/someuser-2026-11-08-inlay-dovetails-pt-2-cleaning-up      | Inlay Dovetails Pt. 2
```

To find what's on TikTok but not yet on YouTube, compare:

```bash
bootleg tiktok index ~/Videos/tiktok | head -20   # downloaded, newest first
bootleg youtube shorts @someuser                  # titles of the ~48 newest Shorts
```

`shorts` reads the channel's public Shorts tab, so it needs no login or quota.
Scheduled Shorts don't show up there until they publish.

### 2. Build the schedule

One video per day, starting on `--start`:

```bash
bootleg youtube schedule picks.txt --start 2026-12-01 --time 19:00 --dir batches/2026-12
```

This copies each video into `batches/2026-12/videos/` and writes
`schedule.csv`. Each row gets the full caption as the description and the
caption's hashtags (or `default_tags`) plus `shorts` as tags, and is private,
scheduled, and not made for kids. It won't replace an existing `schedule.csv`
unless you pass `--force`.

If the sidecar names someone else's sound, a credit line is added to the end of
the description:

```
Original sound by Steven K. (TikTok)
"Song Name" by Some Band (TikTok)
```

Your own sounds get no credit line. Sidecars downloaded before audio was
recorded have no `Audio:` line, so check those by hand. Review and edit the CSV
before uploading.

### 3. Upload

```bash
bootleg youtube upload batches/2026-12 --dry-run   # check every row, upload nothing
bootleg youtube upload batches/2026-12
```

Videos already in `uploads.json` are skipped, so re-running is safe. Uploads
are spaced out (`--delay`, default 45s). The API allows only a few uploads per
day; if the quota runs out the batch stops, and you re-run it after the quota
resets at midnight Pacific. Every video must be uploaded before its publish
time.

### 4. Fix descriptions later

Edit `schedule.csv`, then:

```bash
bootleg youtube update-descriptions batches/2026-12 --dry-run
bootleg youtube update-descriptions batches/2026-12
```

Only the description changes; title, tags and schedule are left alone.

## Schedule format

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

## Configuration

Under the `youtube:` key in `.bootleg.yml` (see the
[README](../README.md#configuration)). Command-line flags override these.

```yaml
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

## Troubleshooting

- **Login expired or revoked:** run `bootleg youtube auth` again (Testing-mode
  logins last 7 days).
- **"Access blocked: can only be used within its organization":** the consent
  screen's audience is Internal; switch it to External and add yourself as a
  test user.
- **Shows under "Videos" right after upload:** normal while it processes. It
  moves to Shorts once processing finishes (vertical and 3 minutes or less).
- **Uploads locked to private:** unaudited API projects can have this. If
  Studio shows a lock notice, set the schedule by hand in Studio.
- **`quotaExceeded`:** the daily quota is used up; re-run the same batch after
  midnight Pacific.

## Credits

A Ruby port of
[youtube-shorts-scheduler](https://github.com/padderzahoor/youtube-shorts-scheduler)
by [Padder Zahoor](https://github.com/padderzahoor), including its CSV schedule
format.
