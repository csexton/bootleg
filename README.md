# Sub-Etha

> "where it would be broadcast out over the Sub-Etha-Net for instantaneous retrieval anywhere in the Galaxy."

― Douglas Adams, *Mostly Harmless*

A command-line utility for downloading, archiving, and publishing videos across social media platforms.

## About

Sub-Etha keeps a local archive of your videos and makes it easy to distribute them across multiple platforms without relying on any one service.

Download once. Archive forever. Publish anywhere.

Don't Panic.

## Installation

Requires Ruby 3.0+.

```bash
git clone <this repo> && cd subetha
bin/setup                 # bundle install
bundle exec exe/subetha --help
```

Or build and install the gem locally:

```bash
bundle exec rake install
subetha --help
```

## Usage

Commands are grouped by platform:

```
subetha PLATFORM COMMAND [options]
```

| Platform | Command    | Description                                  |
|----------|------------|----------------------------------------------|
| `tiktok` | `download` | Download videos and photo posts with metadata |
| `tiktok` | `list`     | Print the video URLs on a profile            |

More platforms (YouTube uploads first, then Instagram and others) will follow the
same shape.

## TikTok

Downloads TikTok videos and photos without watermarks, along with a metadata
sidecar for each post.

```bash
# Download a video to the current directory
subetha tiktok download https://www.tiktok.com/@someuser/video/1234567890

# Specify an output directory
subetha tiktok download --output-dir ~/Videos/tiktok https://www.tiktok.com/@someuser/video/1234567890

# Save sidecar as JSON instead of plain text
subetha tiktok download --json https://www.tiktok.com/@someuser/video/1234567890

# Download multiple URLs
subetha tiktok download URL1 URL2 URL3

# List video URLs for a profile (URLs to stdout, status to stderr)
subetha tiktok list https://www.tiktok.com/@someuser

# Fetch more pages of a profile
subetha tiktok list --pages 3 https://www.tiktok.com/@someuser

# Archive a whole profile
subetha tiktok list --pages 10 https://www.tiktok.com/@someuser | xargs subetha tiktok download
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

## Configuration

Defaults live in a YAML file, with one top-level key per platform. The file in
the current directory takes precedence over the one in your home directory, and
command-line flags override both.

- `~/.subetha.yml` — user-wide defaults
- `./.subetha.yml` — per-project override

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
```

## Development

```bash
bin/setup            # install dependencies
bundle exec rake     # run the specs
bin/console          # IRB with subetha loaded
```

Specs never touch the network; the HTTP layer is always stubbed.

## Credits

The TikTok downloader began as [archivetok](https://github.com/csexton/archivetok),
a Ruby port of [tiktok-downloader-console](https://github.com/RehanDias/tiktok-downloader-console)
by [rehandiazz](https://github.com/RehanDias), which provides the original Node.js
implementation and the fallback API endpoint.

## License

MIT. See [LICENSE](LICENSE).
