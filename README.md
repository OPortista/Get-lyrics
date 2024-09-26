# Spotify Lyrics Downloader & FLAC Renamer

This script was originally designed for personal use, but I’m sharing it in case others find themselves in the same situation.             
Its primary function is to download synchronized lyrics (.LRC) from the Spotify API and embed them into the "lyrics" tag of your FLAC files.  
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

### Search for Lyrics by Album Name
To download lyrics for a specific album:
```bash
./get-lyrics.sh -a "ALBUM_NAME"
```

### Search for Lyrics by Album ID
If you already have the Spotify album ID, you can use it directly:
```bash
./get-lyrics.sh -i "ALBUM_ID"
```

### Rename FLAC Files Only
The `-r` option can be used alongside any of the lyrics search options (`-a`, `-A`, or `-i`), but **it will only rename the FLAC files without downloading lyrics**. For example:

- Rename the files by artist name:
  ```bash
  ./get-lyrics.sh -A "ARTIST_NAME" -r
  ```

- By album name:
  ```bash
  ./get-lyrics.sh -a "ALBUM_NAME" -r
  ```

- By album ID:
  ```bash
  ./get-lyrics.sh -i "ALBUM_ID" -r
  ```

## Renaming Function

This feature is particularly useful for renaming rap music files that include many featured artists. It will rename your FLAC files according to the following format:

- **Single Disc Albums**:  
  `[track_number]. [title]`
  
- **Multi-Disc Albums**:  
  `[discnumber][track_number]. [title]`
  
- **Tracks with Featuring Artists**:  
  `[track_number]. [title] feat [other_artist]`

### File Naming Requirements

Your FLAC files must be named with the appropriate track numbers at the beginning. The script will process files that follow these formats:

- **Single Disc Album**:  
  ```
  01 ...
  02 ...
  ...
  ```

- **Multi-Disc Album**:  
  ```
  101 ...   # First disc, track 1
  102 ...   # First disc, track 2
  ...
  201 ...   # Second disc, track 1
  202 ...   # Second disc, track 2
  ...
  ```

## License

Feel free to use and modify the script to fit your needs. No specific license is applied, but attribution is appreciated if you find it useful.