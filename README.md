# Spotify Lyrics Downloader & FLAC Renamer

This script was originally designed for personal use, but I’m sharing it in case others find themselves in the same situation. Its primary function is to download synchronized lyrics (.LRC) from the Spotify API and embed them into the "lyrics" tag of your FLAC files.  
Additionally, it includes an optional feature to rename FLAC files according to specific naming conventions, particularly useful for albums with multiple artists and features.

## Prerequisites

1. **Install `fzf`**  
   Ensure that `fzf` is installed on your system, as it is required for filtering results.

2. **Configure Spotify API Credentials**  
   At the beginning of the script, fill in the two required Spotify variables with your API credentials.

3. **(Optional) File Renaming**  
   If you want to use the file renaming feature, place your FLAC files in the same directory as the script.

## Usage

### Search for Lyrics by Artist
To download lyrics for a specific artist:
```bash
./get-lyrics.sh -A "ARTIST_NAME"
```

### Search for Lyrics by Album
To download lyrics for a specific album:
```bash
./get-lyrics.sh -a "ALBUM_NAME"
```

### Rename FLAC Files Only
If you only want to use the file renaming function, add the `-r` option:
```bash
./get-lyrics.sh -A "ARTIST_NAME" -r
```

## Renaming Function

This feature is particularly useful for renaming rap music files that include many featured artists. It will rename your FLAC files according to the following format:

- **Single Disc Albums**:  
  `[track_number]. [title]`
  
- **Multi-Disc Albums**:  
  `[discnumber][track_number]. [title]`
  
- **Tracks with Featuring Artists**:  
  `[discnumber][track_number]. [title] feat [other_artist]`

### File Naming Requirements

Your FLAC files must be named with the appropriate track numbers at the beginning. The script will process files that follow these formats:

- **Single Disc Album**:  
  ```
  01 TITLE
  02 TITLE
  ...
  ```

- **Multi-Disc Album**:  
  ```
  101 TITLE   # First disc, track 1
  102 TITLE   # First disc, track 2
  ...
  201 TITLE   # Second disc, track 1
  202 TITLE   # Second disc, track 2
  ...
  ```

## License

Feel free to use and modify the script to fit your needs. No specific license is applied, but attribution is appreciated if you find it useful.