This script was originally designed just for me.  
The aim is to download the sync lyrics (.LRC) from the Spotify API and write them in the "lyrics" tag of my flac files.  
I'm sharing it in case people are in the same situation as me.  


Prerequisite:  
1-Install fzf.  
2-Fill the two Spotify variables at the beginning of the script.  
3-(optional) if you want to rename your flac files, put them in the same directory as the script.


Usage:  
Search by artist:  
```
./get-lyrics.sh -A "ARTIST_NAME"
```

Search by album:  
```
./get-lyrics.sh -a "ALBUM_NAME"
```

If you want to only use rename function, use the same but end with -r :  
Example :  
```
./get-lyrics.sh -A "ARTIST_NAME" -r
```

For the rename function, you're flac files need to be name with the good number at the beginning.  
One disc album :  
01 TITLE  
02 TITLE  
....

More disc album :  
101 TITLE  
102 TITLE  
...  
201 TITLE  
202 TITLE  
...
