# Bootleg

A command-line utility for downloading, archiving, and publishing videos across social media platforms.

## About

Bootleg keeps a local archive of your videos and makes it easy to distribute them across multiple platforms without relying on any one service.

> "Can't stop the signal, Mal."

― Mr. Universe, Serenity (2005)

## Installation

Requires Ruby 3.0+. Bootleg runs straight from a checkout, no `bundle exec`
needed:

```bash
git clone https://github.com/csexton/bootleg.git && cd bootleg
bin/setup
bin/bootleg --help
```

To call it as plain `bootleg`, as the docs do, put `bin/` on your `PATH`:

```bash
export PATH="$HOME/src/bootleg/bin:$PATH"
```

## Usage

```
bootleg PLATFORM COMMAND [options]
```

| Platform | Commands | Docs |
|----------|----------|------|
| `tiktok` | `download`, `list`, `index` | [docs/tiktok.md](docs/tiktok.md) |
| `youtube` | `auth`, `schedule`, `upload`, `update-descriptions`, `shorts` | [docs/youtube.md](docs/youtube.md) (includes Google Cloud setup) |

Run `bootleg PLATFORM --help` for options. Typical cross-post, TikTok to YouTube:

```bash
bootleg tiktok list https://www.tiktok.com/@someuser | xargs bootleg tiktok download
bootleg youtube schedule picks.txt --start 2026-12-01 --dir batches/2026-12
bootleg youtube upload batches/2026-12
```

## Configuration

Defaults live in `~/.bootleg.yml`, or `./.bootleg.yml` to override per
directory, with one key per platform. Flags override both. Each platform's doc
lists its keys.

```yaml
tiktok:
  output_dir: ~/Videos/tiktok
youtube:
  timezone: America/New_York
```

## Development

```bash
bundle exec rake     # run the specs (offline; HTTP is always stubbed)
bin/console          # IRB with bootleg loaded
```

Each platform is a namespace under `lib/bootleg/` with its own `CLI` class,
registered in `Bootleg::CLI::PLATFORMS`.

## Credits

Ports of [archivetok](https://github.com/csexton/archivetok) (itself based on
[tiktok-downloader-console](https://github.com/RehanDias/tiktok-downloader-console))
and [youtube-shorts-scheduler](https://github.com/padderzahoor/youtube-shorts-scheduler).
See each platform's doc for details.

## License

MIT. See [LICENSE](LICENSE).
