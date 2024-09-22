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

search_spotify() {
	local search_query=$1
	local access_token=$2
	encoded_query=$(echo "$search_query" | jq -sRr @uri)
	curl -s -X GET "https://api.spotify.com/v1/search?q=$encoded_query&type=artist&limit=15" \
		-H "Authorization: Bearer $access_token"
}

search_album_spotify() {
	local search_query=$1
	local access_token=$2
	encoded_query=$(echo "$search_query" | jq -sRr @uri)
	curl -s -X GET "https://api.spotify.com/v1/search?q=$encoded_query&type=album&limit=40" \
		-H "Authorization: Bearer $access_token"
}

display_results() {
	local json_results=$1
	echo ""
	echo "$json_results" | jq -r '.artists.items[] | "\(.name) - ID: \(.id)"' | fzf --height 60% --reverse --inline-info --header "Choose an artist :"
}

display_album_results() {
	local json_results=$1
	echo ""
	echo "$json_results" | jq -r '.albums.items[] | "\(.name) by \(.artists[0].name) - ID: \(.id)"' | fzf --height 60% --reverse --inline-info --header "Choose an album :"
}

get_artist_albums() {
	local artist_id=$1
	local access_token=$2
	curl -s -X GET "https://api.spotify.com/v1/artists/$artist_id/albums?include_groups=album&limit=40" \
		-H "Authorization: Bearer $access_token"
}

display_artist_albums() {
	local json_results=$1
	echo ""
	echo "$json_results" | jq -r '.items[] | "\(.name) - ID: \(.id) (Tracks: \(.total_tracks))"' | sort | fzf --height 40% --reverse --inline-info --header "Choose an album :"
}

get_album() {
	local album_id="$1"
	local token=$(get_access_token)
	curl -s -X GET \
		-H "Authorization: Bearer $token" \
		"https://api.spotify.com/v1/albums/$album_id" | jq .
}

get_track() {
	local track_id="$1"
	local token=$(get_access_token)
	curl -s -X GET \
		-H "Authorization: Bearer $token" \
		"https://api.spotify.com/v1/tracks/$track_id" | jq .
}

download_lrc() {
	echo
	details=$(get_album "$selected_id_album")
	artist=$(echo $details | jq -r '.artists[].name' | tr '\n' ' ')
	album=$(echo $details | jq -r '.name')
	disc_number=$(echo $details | jq '.tracks.items | map(.disc_number) | unique | length')
	disc_count=$(echo $details | jq '.tracks.items | map(.disc_number) | unique | length')
	total_tracks=$(echo $details | jq -r '.total_tracks')
	count="0"
	echo -e "${BOLD} $artist- $album ($disc_number discs | $total_tracks tracks)${RESET}"
	echo
	while IFS= read -r track; do
		{
			secondary_artists=$(echo "$track" | jq -r '.artists[].name' | tail -n +2)
			track_number=$(echo "$track" | jq -r '.track_number')
			formatted_track_number=$(printf "%02d" "$track_number") # Formatage en 2 chiffres
			disc_number=$(echo "$track" | jq -r '.disc_number')
			id=$(echo "$track" | jq -r '.id')
			name=$(echo "$track" | jq -r '.name')
			if [[ "$name" == *\/* ]]; then
				name=$(echo "$name" | tr '/' '_')
			fi
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
	details=$(get_album "$selected_id_album")
	artist=$(echo $details | jq -r '.artists[].name' | tr '\n' ' ')
	album=$(echo $details | jq -r '.name')
	disc_count=$(echo $details | jq '.tracks.items | map(.disc_number) | unique | length')
	total_tracks=$(echo $details | jq -r '.total_tracks')
	echo -e "${BOLD} $artist - $album ($disc_count discs | $total_tracks tracks)${RESET}"
	echo
	while IFS= read -r track; do
		{
			secondary_artists=$(echo "$track" | jq -r '.artists[].name' | tail -n +2)
			track_number=$(echo "$track" | jq -r '.track_number')
			formatted_track_number=$(printf "%02d" "$track_number") # Formatage en 2 chiffres
			disc_number=$(echo "$track" | jq -r '.disc_number')
			name=$(echo "$track" | jq -r '.name')
			if [[ "$name" == *\/* ]]; then
				name=$(echo "$name" | tr '/' '_')
			fi
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
			echo "$formatted_name"
		}
	done < <(get_album "$selected_id_album" | jq -c '.tracks.items[]')
	echo
	echo "CONFIRM ? (y or n)"
	read -r response
	case "$response" in
		y)
			echo
			details=$(get_album "$selected_id_album")
			artist=$(echo $details | jq -r '.artists[].name' | tr '\n' ' ')
			album=$(echo $details | jq -r '.name')
			disc_count=$(echo $details | jq '.tracks.items | map(.disc_number) | unique | length')
			total_tracks=$(echo $details | jq -r '.total_tracks')

			echo -e "${BOLD} $artist - $album ($disc_count discs | $total_tracks tracks)${RESET}"
			echo
			while IFS= read -r track; do
				{
					secondary_artists=$(echo "$track" | jq -r '.artists[].name' | tail -n +2)
					track_number=$(echo "$track" | jq -r '.track_number')
					formatted_track_number=$(printf "%02d" "$track_number") # Formatage en 2 chiffres
					disc_number=$(echo "$track" | jq -r '.disc_number')
					name=$(echo "$track" | jq -r '.name')
					if [[ "$name" == *\/* ]]; then
						name=$(echo "$name" | tr '/' '_')
					fi
					if [ -n "$secondary_artists" ]; then
						feat_artists=$(echo "$secondary_artists" | paste -sd ", " | sed 's/,/, /g')
						base_name="$name feat $feat_artists"
					else
						base_name="$name"
					fi
					if [[ "$disc_count" -gt 1 ]]; then
						# Si l'album a plusieurs disques, inclure le numéro de disque dans le format `disc_numbertrack_number`
						formatted_name="${disc_number}${formatted_track_number}. $base_name"
					else
						formatted_name="${formatted_track_number}. $base_name"
					fi
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
				}
			done < <(get_album "$selected_id_album" | jq -c '.tracks.items[]')
			;;
		*)
			exit 0
			;;
	esac
}
write_tag () {
	if [[ "count" -gt 0 ]]; then
		echo "Write lyrics ? (y or n)"
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
						# Lire le contenu du fichier .lrc
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
					echo "Clean lrc files ? (y or n)"
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
		echo "ERROR : Unable to get token."
		exit 1
	fi
	album_results=$(search_album_spotify "$album_name" "$access_token")
	selected_album=$(display_album_results "$album_results")
	if [ -z "$selected_album" ]; then
		echo "No album choosed."
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
	access_token=$(get_access_token)
	if [ -z "$access_token" ]; then
		echo "ERROR : Unable to get token."
		exit 1
	fi
	search_results=$(search_spotify "$artist_name" "$access_token")
	selected_artist=$(display_results "$search_results")
	if [ -z "$selected_artist" ]; then
		echo "No artist choosed."
		exit 1
	fi
	selected_id_artist=$(echo "$selected_artist" | awk -F ' - ID: ' '{print $2}' | tr -d '\n')
	artist_albums=$(get_artist_albums "$selected_id_artist" "$access_token")
	selected_album=$(display_artist_albums "$artist_albums")
	if [ -z "$selected_album" ]; then
		echo "No album choosed."
		exit 1
	fi
	selected_id_album=$(echo "$selected_album" | awk -F '- ID: | \\(Tracks' '{print $2}' | tr -d '\n')
	if [ "$last_arg" == "-r" ]; then
		rename_file
		exit 0
	else
		download_lrc
	fi
else
	echo
	echo "Enter the artist name to search :"
	read -r search_query
	access_token=$(get_access_token)
	if [ -z "$access_token" ]; then
		echo ERROR : Unable to get token."
		exit 1
	fi
	search_results=$(search_spotify "$search_query" "$access_token")
	selected_artist=$(display_results "$search_results")
	if [ -z "$selected_artist" ]; then
		echo "No artist choosed."
		exit 1
	fi
	selected_id_artist=$(echo "$selected_artist" |  awk -F ' - ID: ' '{print $2}' | tr -d '\n')
	artist_albums=$(get_artist_albums "$selected_id_artist" "$access_token")
	selected_album=$(display_artist_albums "$artist_albums")
	if [ -z "$selected_album" ]; then
		echo "No album chooses."
		exit 1
	fi
	selected_id_album=$(echo "$selected_album" | awk -F '- ID: | \\(Tracks' '{print $2}' | tr -d '\n')
	if [ "$last_arg" == "-r" ]; then
		rename_file
		exit 0
	else
		download_lrc
	fi
fi
write_tag
echo "Rename files ? (y or n)"
read -r response
case "$response" in
	y)
		rename_file
		;;
	*)
		exit 0
		;;
esac