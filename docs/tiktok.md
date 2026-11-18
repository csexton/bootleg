# TikTok

Downloads TikTok videos and photos without watermarks, along with a metadata
sidecar for each post. No account or login is needed.

## Commands

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
# (defaults to the configured output_dir)
bootleg tiktok index ~/Videos/tiktok
```

The output directory is created automatically if it doesn't exist. `download`
takes only video and photo URLs; pass profile URLs to `list`.

## Output

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

## Sidecar format

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

The `Audio` lines name the sound the post uses, so it can be credited (see
[YouTube](youtube.md#2-build-the-schedule)). An "original sound" under the
poster's own name is marked `(own audio)`. Posts with no sound info omit them.

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

## Configuration

Under the `tiktok:` key in `.bootleg.yml` (see the
[README](../README.md#configuration)). Command-line flags override these.

```yaml
tiktok:
  output_dir: ~/Videos/tiktok   # default: the current directory
  json_sidecar: true            # default: false
  pages: 1                      # profile pages for `list`

  # Filename components (shown with defaults)
  filename_username: true
  filename_date: true
  filename_slug: true
  filename_id: false
```

## Credits

Began as [archivetok](https://github.com/csexton/archivetok), a Ruby port of
[tiktok-downloader-console](https://github.com/RehanDias/tiktok-downloader-console)
by [rehandiazz](https://github.com/RehanDias), which provides the original
Node.js implementation and the fallback API endpoint.
