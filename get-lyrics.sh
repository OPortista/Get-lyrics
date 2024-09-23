#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[0;1m'
RESET='\033[0m'
CHECKs='\xE2\x9C\x94'
CROSSs='\xE2\x9D\x8C'
SKIPs='\xE2\x87\xA8'
CHECK="${GREEN}${CHECKs}${RESET}"
CROSS="${RED}${CROSSs}${RESET}"
SKIP="${BLUE}${SKIPs}${RESET}"

last_arg="${@: -1}"

SPOTIFY_CLIENT_ID="xxxxx"
SPOTIFY_CLIENT_SECRET="xxxxx"

album_name=""
artist_name=""
selected_id_album=""

get_access_token() {
    local response=$(curl -s -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -u "$SPOTIFY_CLIENT_ID:$SPOTIFY_CLIENT_SECRET" \
        -d "grant_type=client_credentials" \
        https://accounts.spotify.com/api/token)
    echo $(echo $response | jq -r '.access_token')
}

search() {
    local search_query=$1
    local access_token=$2
    local type=$3
    if [[ $type == "album" ]]; then
        limit=15
    else
        limit=40
    fi
    encoded_query=$(echo "$search_query" | jq -sRr @uri)
    curl -s -X GET "https://api.spotify.com/v1/search?q=$encoded_query&type=$type&limit=$limit" \
        -H "Authorization: Bearer $access_token"
}

display_results() {
    local json_results=$1
    local type=$2
    echo ""
    case "$type" in
        "artists")
            echo "$json_results" | jq -r '.artists.items[] | "\(.name) - ID: \(.id)"' | \
            fzf --height 60% --reverse --inline-info --header "Choose an artist :"
            ;;
        "albums")
            echo "$json_results" | jq -r '.albums.items[] | "\(.name) by \(.artists[0].name) - ID: \(.id)"' | \
            fzf --height 60% --reverse --inline-info --header "Choose an album :"
            ;;
        "artist_albums")
            echo "$json_results" | jq -r '.items[] | "\(.name) - ID: \(.id) (Tracks: \(.total_tracks))"' | \
            sort | fzf --height 40% --reverse --inline-info --header  "Choose an album :"
            ;;
    esac
}

get_artist_albums() {
    local artist_id=$1
    local access_token=$2
    curl -s -X GET "https://api.spotify.com/v1/artists/$artist_id/albums?include_groups=album&limit=40" \
        -H "Authorization: Bearer $access_token"
}

get_album() {
    local album_id="$1"
    local token=$(get_access_token)
    curl -s -X GET \
        -H "Authorization: Bearer $token" \
        "https://api.spotify.com/v1/albums/$album_id" | jq .
}

get_album_details() {
    details=$(get_album "$selected_id_album")
    artist=$(echo $details | jq -r '.artists[].name' | tr '\n' ' ')
    album=$(echo $details | jq -r '.name')
    disc_number=$(echo $details | jq '.tracks.items | map(.disc_number) | unique | length')
    disc_count=$(echo $details | jq '.tracks.items | map(.disc_number) | unique | length')
    total_tracks=$(echo $details | jq -r '.total_tracks')
}

format_name() {
    secondary_artists=$(echo "$track" | jq -r '.artists[].name' | tail -n +2)
    track_number=$(echo "$track" | jq -r '.track_number')
    formatted_track_number=$(printf "%02d" "$track_number")
    disc_number=$(echo "$track" | jq -r '.disc_number')
    id=$(echo "$track" | jq -r '.id')
    name=$(echo "$track" | jq -r '.name')
    name="${name//[\/?*]/_}"

    if [ -n "$secondary_artists" ]; then
        feat_artists=$(echo "$secondary_artists" | paste -sd ", " | sed 's/,/, /g')
        base_name="$name feat $feat_artists"
    else
        base_name="$name"
    fi

    if [[ "$disc_count" -gt 1 ]]; then
        formatted_name="${disc_number}${formatted_track_number}. $base_name"
    else
        formatted_name="${formatted_track_number}. $base_name"
    fi
}

download_lrc() {
    echo
    get_album_details
    count="0"

    echo -e "${BOLD} $artist- $album ($disc_number discs | $total_tracks tracks)${RESET}"
    echo

    while IFS= read -r track; do
        {
            format_name
            output_file="${formatted_name}.lrc"
            json_lyrics=$(curl -s "https://spotify-lyrics-api-pi.vercel.app/?trackid=${id}&format=lrc" | jq)

            if [[ "$json_lyrics" == *"not available"* ]]; then
                echo -e "${CROSS}$formatted_name"
                continue
            fi

            echo "$json_lyrics" | jq -c '.lines[]' | while read -r line; do
                time_tag=$(echo "$line" | jq -r '.timeTag')
                words=$(echo "$line" | jq -r '.words')
                echo "[$time_tag] $words" >> "$output_file"
            done

            echo -e "${CHECK} $formatted_name"
            count=$((count + 1))
        }
    done < <(get_album "$selected_id_album" | jq -c '.tracks.items[]')

    echo
    echo "$count/$total_tracks lyrics downloaded"
    echo
}

rename_file() {
    echo
    get_album_details

    echo -e "${BOLD} $artist- $album ($disc_count discs | $total_tracks tracks)${RESET}"
    echo

    tracks=$(echo "$details" | jq -c '.tracks.items[]')

    while IFS= read -r track; do
        format_name
        echo "$formatted_name"
    done <<< "$tracks"

    echo
    echo "CONFIRM ? (y or n)"
    read -r response

    if [[ "$response" == "y" ]]; then
        echo
        while IFS= read -r track; do
            format_name
            for file in *.flac; do
                if [[ -f "$file" ]]; then
                    filename=$(basename "$file" .flac)
                    file_track_number=$(echo "$filename" | grep -oE '^[0-9]+')

                    if [[ "$disc_count" -gt 1 ]]; then
                        expected_track_number="${disc_number}${formatted_track_number}"
                        if [[ "$file_track_number" == "$expected_track_number" ]]; then
                            new_filename="${formatted_name}.flac"
                            mv -v "$file" "$new_filename"
                        fi
                    else
                        if [[ "$file_track_number" == "$formatted_track_number" ]]; then
                            new_filename="${formatted_name}.flac"
                            mv -v "$file" "$new_filename"
                        fi
                    fi
                fi
            done
        done <<< "$tracks"
    else
        exit 0
    fi
}

write_tag() {
    if [[ "count" -gt 0 ]]; then
        echo "Write lyrics? (y or n)"
        read -r response
        case "$response" in
            y)
                echo
                echo -e "${BOLD} Writing lyrics...${RESET}"
                count="0"
                for flac_file in *.flac; do
                    flac_number=$(echo "$flac_file" | grep -oP '^\d+')
                    lrc_file=$(ls | grep -P "^${flac_number}.*\.lrc")

                    if [ -n "$lrc_file" ]; then
                        lyrics=$(cat "$lrc_file")
                        metaflac --remove-tag="lyrics" --set-tag="lyrics=$lyrics" "$flac_file"
                        echo -e "${CHECK} $flac_file"
                        rm "$lrc_file"
                        count=$((count + 1))
                    else
                        echo -e "${SKIP} $flac_file"
                    fi
                done

                echo
                echo "$count/$total_tracks lyrics written"
                echo
                ;;
            n)
                if [[ "count" -gt 0 ]]; then
                    echo
                    echo "Clean lrc files? (y or n)"
                    read -r response
                    case "$response" in
                        y)
                            rm -v *.lrc
                            echo
                            ;;
                        *)
                            rename_file
                            ;;
                    esac
                fi
                ;;
            *)
                rename_file
                ;;
        esac
    fi
}

main() {
    access_token=$(get_access_token)
    if [ -z "$access_token" ]; then
        echo "ERROR: Unable to get token."
        exit 1
    fi

    search_results=$(search "$artist_name" "$access_token" artist)
    selected_artist=$(display_results "$search_results" artists)

    if [ -z "$selected_artist" ]; then
        echo "No artist chosen."
        exit 1
    fi

    selected_id_artist=$(echo "$selected_artist" | awk -F ' - ID: ' '{print $2}' | tr -d '\n')
    artist_albums=$(get_artist_albums "$selected_id_artist" "$access_token")
    selected_album=$(display_results "$artist_albums" artist_albums)

    if [ -z "$selected_album" ]; then
        echo "No album chosen."
        exit 1
    fi

    selected_id_album=$(echo "$selected_album" | awk -F '- ID: | \\(Tracks' '{print $2}' | tr -d '\n')

    if [ "$last_arg" == "-r" ]; then
        rename_file
        exit 0
    else
        download_lrc
    fi
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -a|--album)
            album_name="$2"
            shift 2
            ;;
        -A|--artist)
            artist_name="$2"
            shift 2
            ;;
        -i|--id)
            selected_id_album="$2"
            shift 2
            ;;
        -r|--rename)
            shift 2
            break
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Usage: $0 -a <album> [-A <artist>] -i <id>"
            exit 1
            ;;
    esac
done

if [[ -n "$selected_id_album" ]]; then
    download_lrc
elif [[ -n "$album_name" ]]; then
    access_token=$(get_access_token)
    if [ -z "$access_token" ]; then
        echo "ERROR: Unable to get token."
        exit 1
    fi

    album_results=$(search "$album_name" "$access_token" album)
    selected_album=$(display_results "$album_results" albums)

    if [ -z "$selected_album" ]; then
        echo "No album chosen."
        exit 1
    fi

    selected_id_album=$(echo "$selected_album" | awk -F ' - ID: ' '{print $2}' | tr -d '\n')

    if [ "$last_arg" == "-r" ]; then
        rename_file
        exit 0
    else
        download_lrc
    fi
elif [[ -n "$artist_name" ]]; then
    main
else
    echo
    echo "Enter the artist name to search:"
    read -r artist_name
    main
fi

write_tag

if ls *.flac 1> /dev/null 2>&1; then
    echo "Rename files? (y or n)"
    read -r response

    case "$response" in
        y)
            rename_file
            ;;
        *)
            exit 0
            ;;
    esac
fi