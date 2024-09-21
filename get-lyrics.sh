#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAS='\033[0;1m'
RESET='\033[0m'
CHECKs='\xE2\x9C\x94'
CROSSs='\xE2\x9D\x8C'
SKIPs='\xE2\x87\xA8'
CHECK="${GREEN}${CHECKs}${RESET}"
CROSS="${RED}${CROSSs}${RESET}"
SKIP="${BLUE}${SKIPs}${RESET}"

last_arg="${@: -1}"

# Spotify API credentials
SPOTIFY_CLIENT_ID="xxxxx"
SPOTIFY_CLIENT_SECRET="xxxxx"

# Variables pour les options
album_name=""
artist_name=""
selected_id_album=""

# Fonction pour obtenir un token d'accès
get_access_token() {
	local response=$(curl -s -X POST \
		-H "Content-Type: application/x-www-form-urlencoded" \
		-u "$SPOTIFY_CLIENT_ID:$SPOTIFY_CLIENT_SECRET" \
		-d "grant_type=client_credentials" \
		https://accounts.spotify.com/api/token)
	echo $(echo $response | jq -r '.access_token')
}

# Fonction pour rechercher des artistes
search_spotify() {
	local search_query=$1
	local access_token=$2

	# Encode le query pour l'URL
	encoded_query=$(echo "$search_query" | jq -sRr @uri)

	# Requête de recherche Spotify avec limite ajustée
	curl -s -X GET "https://api.spotify.com/v1/search?q=$encoded_query&type=artist&limit=15" \
		-H "Authorization: Bearer $access_token"
}

# Fonction pour rechercher des albums directement
search_album_spotify() {
	local search_query=$1
	local access_token=$2

	# Encode le query pour l'URL
	encoded_query=$(echo "$search_query" | jq -sRr @uri)

	# Requête de recherche Spotify pour un album
	curl -s -X GET "https://api.spotify.com/v1/search?q=$encoded_query&type=album&limit=40" \
		-H "Authorization: Bearer $access_token"
}

# Fonction pour afficher les artistes trouvés
display_results() {
	local json_results=$1

	# Parser et afficher les résultats
	echo ""
	echo "$json_results" | jq -r '.artists.items[] | "\(.name) - ID: \(.id)"' | fzf --height 60% --reverse --inline-info --header "Choisissez un artiste :"
}

# Fonction pour afficher les albums trouvés
display_album_results() {
	local json_results=$1
	echo ""
	echo "$json_results" | jq -r '.albums.items[] | "\(.name) by \(.artists[0].name) - ID: \(.id)"' | fzf --height 60% --reverse --inline-info --header "Choisissez un album :"
}

# Fonction pour récupérer tous les albums d'un artiste sélectionné
get_artist_albums() {
	local artist_id=$1
	local access_token=$2

	# Requête pour récupérer les albums d'un artiste
	curl -s -X GET "https://api.spotify.com/v1/artists/$artist_id/albums?include_groups=album&limit=40" \
		-H "Authorization: Bearer $access_token"
}

# Fonction pour afficher les albums d'un artiste
display_artist_albums() {
	local json_results=$1

	# Afficher les albums de l'artiste
	echo ""
	echo "$json_results" | jq -r '.items[] | "\(.name) - ID: \(.id) (Tracks: \(.total_tracks))"' | sort | fzf --height 40% --reverse --inline-info --header "Choisissez un album :"
}

# Obtenir des informations sur un album
get_album() {
	local album_id="$1"
	local token=$(get_access_token)

	curl -s -X GET \
		-H "Authorization: Bearer $token" \
		"https://api.spotify.com/v1/albums/$album_id" | jq .
}

# Fonction pour obtenir les détails d'une piste
get_track() {
	local track_id="$1"
	local token=$(get_access_token)

	curl -s -X GET \
		-H "Authorization: Bearer $token" \
		"https://api.spotify.com/v1/tracks/$track_id" | jq .
}

# Fonction pour télécharger les paroles au format .lrc
download_lrc() {
	echo
	details=$(get_album "$selected_id_album")
	artist=$(echo $details | jq -r '.artists[].name' | tr '\n' ' ')
	album=$(echo $details | jq -r '.name')
	disc_number=$(echo $details | jq '.tracks.items | map(.disc_number) | unique | length')
	disc_count=$(echo $details | jq '.tracks.items | map(.disc_number) | unique | length')
	total_tracks=$(echo $details | jq -r '.total_tracks')
	count="0"
	echo -e "${GRAS} $artist- $album ($disc_number discs | $total_tracks tracks)${RESET}"
	echo

	# Utiliser un bloc de commande pour éviter les sous-shells

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
				# Si l'album a plusieurs disques, inclure le numéro de disque dans le format `disc_numbertrack_number`
				formatted_name="${disc_number}${formatted_track_number}. $base_name"
			else
				# Si l'album n'a qu'un seul disque, ne pas inclure le numéro de disque, juste le numéro de piste
				formatted_name="${formatted_track_number}. $base_name"
			fi

			output_file="${formatted_name}.lrc"

			# Récupérer les paroles au format JSON via l'API
			json_lyrics=$(curl -s "https://spotify-lyrics-api-pi.vercel.app/?trackid=${id}&format=lrc" | jq)

			if [[ "$json_lyrics" == *"not available"* ]]; then
				echo -e "${CROSS}$formatted_name"
				continue
			fi

			# Parcourir les lignes de paroles et les ajouter au fichier .lrc
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

	echo -e "${GRAS} $artist - $album ($disc_count discs | $total_tracks tracks)${RESET}"
	echo

	# Boucle pour chaque piste de l'album
	while IFS= read -r track; do
		{
			# Récupérer les informations de la piste
			secondary_artists=$(echo "$track" | jq -r '.artists[].name' | tail -n +2)
			track_number=$(echo "$track" | jq -r '.track_number')
			formatted_track_number=$(printf "%02d" "$track_number") # Formatage en 2 chiffres
			disc_number=$(echo "$track" | jq -r '.disc_number')
			name=$(echo "$track" | jq -r '.name')

			# Remplacer les caractères spéciaux dans le nom du fichier
			if [[ "$name" == *\/* ]]; then
				name=$(echo "$name" | tr '/' '_')
			fi

			# Si plusieurs artistes, ajouter "feat" avec les artistes secondaires
			if [ -n "$secondary_artists" ]; then
				feat_artists=$(echo "$secondary_artists" | paste -sd ", " | sed 's/,/, /g')
				base_name="$name feat $feat_artists"
			else
				base_name="$name"
			fi

			# Formatage du nom de fichier selon le nombre de disques
			if [[ "$disc_count" -gt 1 ]]; then
				# Si l'album a plusieurs disques, inclure le numéro de disque dans le format `disc_numbertrack_number`
				formatted_name="${disc_number}${formatted_track_number}. $base_name"
			else
				# Si l'album n'a qu'un seul disque, ne pas inclure le numéro de disque, juste le numéro de piste
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

			echo -e "${GRAS} $artist - $album ($disc_count discs | $total_tracks tracks)${RESET}"
			echo

			# Boucle pour chaque piste de l'album
			while IFS= read -r track; do
				{
					# Récupérer les informations de la piste
					secondary_artists=$(echo "$track" | jq -r '.artists[].name' | tail -n +2)
					track_number=$(echo "$track" | jq -r '.track_number')
					formatted_track_number=$(printf "%02d" "$track_number") # Formatage en 2 chiffres
					disc_number=$(echo "$track" | jq -r '.disc_number')
					name=$(echo "$track" | jq -r '.name')

					# Remplacer les caractères spéciaux dans le nom du fichier
					if [[ "$name" == *\/* ]]; then
						name=$(echo "$name" | tr '/' '_')
					fi

					# Si plusieurs artistes, ajouter "feat" avec les artistes secondaires
					if [ -n "$secondary_artists" ]; then
						feat_artists=$(echo "$secondary_artists" | paste -sd ", " | sed 's/,/, /g')
						base_name="$name feat $feat_artists"
					else
						base_name="$name"
					fi

					# Formatage du nom de fichier selon le nombre de disques
					if [[ "$disc_count" -gt 1 ]]; then
						# Si l'album a plusieurs disques, inclure le numéro de disque dans le format `disc_numbertrack_number`
						formatted_name="${disc_number}${formatted_track_number}. $base_name"
					else
						# Si l'album n'a qu'un seul disque, ne pas inclure le numéro de disque, juste le numéro de piste
						formatted_name="${formatted_track_number}. $base_name"
					fi

					# Comparer avec les fichiers .flac dans le dossier
					for file in *.flac; do
						if [[ -f "$file" ]]; then
							filename=$(basename "$file" .flac)
							# Extraire le numéro de piste (les premiers chiffres) du fichier .flac
							file_track_number=$(echo "$filename" | grep -oE '^[0-9]+')

							if [[ "$disc_count" -gt 1 ]]; then
								# Comparer le numéro de piste du fichier avec celui récupéré via l'API
								expected_track_number="${disc_number}${formatted_track_number}"
								if [[ "$file_track_number" == "$expected_track_number" ]]; then
									new_filename="${formatted_name}.flac"
									mv -v "$file" "$new_filename"
								fi
							else
								# Pour un seul disque, comparer directement le numéro de piste
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
# Fonction pour écrire les tags dans les fichiers FLAC
write_tag () {
	if [[ "count" -gt 0 ]]; then
		echo "Write lyrics ? (y or n)"
		read -r response
		case "$response" in
			y)
				echo
				echo -e "${GRAS} Writing lyrics...${RESET}"
				count="0"
				for flac_file in *.flac; do
					# Extraire le numéro du fichier .flac (on suppose que le numéro est au début du nom)
					flac_number=$(echo "$flac_file" | grep -oP '^\d+')

					# Trouver le fichier .lrc correspondant avec le même numéro au début
					lrc_file=$(ls | grep -P "^${flac_number}.*\.lrc")

					# Si un fichier .lrc correspondant est trouvé
					if [ -n "$lrc_file" ]; then
						# Lire le contenu du fichier .lrc
						lyrics=$(cat "$lrc_file")

						# Ajouter le contenu du fichier .lrc dans le tag "LYRICS" du fichier .flac
						metaflac --remove-tag="lyrics" --set-tag="lyrics=$lyrics" "$flac_file" # Ajoute le nouveau tag

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

# Ajout des options via getopts
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
		-r|--rename) # Pour stopper le parsing des options
			shift 2
			break
			;;
		--) # Pour stopper le parsing des options
			shift
			break
			;;
		*)
			echo "Usage: $0 -a <album> [-A <artist>] -i <id>"
			exit 1
			;;
	esac
done

# Logique principale
if [[ -n "$selected_id_album" ]]; then
	download_lrc
elif [[ -n "$album_name" ]]; then
	# Si un album est fourni avec l'option -a
	access_token=$(get_access_token)

	if [ -z "$access_token" ]; then
		echo "Erreur: Impossible d'obtenir un token d'accès."
		exit 1
	fi

	# Rechercher l'album directement sur Spotify
	album_results=$(search_album_spotify "$album_name" "$access_token")

	# Afficher les résultats et demander à l'utilisateur de choisir un album
	selected_album=$(display_album_results "$album_results")

	if [ -z "$selected_album" ]; then
		echo "Aucun album sélectionné."
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
	# Si un artiste est fourni avec l'option -A
	access_token=$(get_access_token)

	if [ -z "$access_token" ]; then
		echo "Erreur: Impossible d'obtenir un token d'accès."
		exit 1
	fi

	# Rechercher l'artiste sur Spotify
	search_results=$(search_spotify "$artist_name" "$access_token")

	# Afficher les résultats et demander à l'utilisateur de choisir un artiste
	selected_artist=$(display_results "$search_results")

	if [ -z "$selected_artist" ]; then
		echo "Aucun artiste sélectionné."
		exit 1
	fi

	selected_id_artist=$(echo "$selected_artist" | awk -F ' - ID: ' '{print $2}' | tr -d '\n')

	# Récupérer tous les albums de l'artiste sélectionné
	artist_albums=$(get_artist_albums "$selected_id_artist" "$access_token")

	# Afficher les albums de l'artiste
	selected_album=$(display_artist_albums "$artist_albums")

	if [ -z "$selected_album" ]; then
		echo "Aucun album sélectionné."
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
	# Si aucun paramètre n'est fourni, demande une recherche manuelle
	echo
	echo "Entrez le nom de l'artiste à rechercher :"
	read -r search_query

	# Obtenir un token d'accès
	access_token=$(get_access_token)

	if [ -z "$access_token" ]; then
		echo "Erreur: Impossible d'obtenir un token d'accès."
		exit 1
	fi

	# Rechercher sur Spotify pour l'artiste
	search_results=$(search_spotify "$search_query" "$access_token")

	# Afficher les résultats
	selected_artist=$(display_results "$search_results")

	if [ -z "$selected_artist" ]; then
		echo "Aucun artiste sélectionné."
		exit 1
	fi
	# Extraire l'ID de l'artiste sélectionné
	selected_id_artist=$(echo "$selected_artist" |  awk -F ' - ID: ' '{print $2}' | tr -d '\n')

	# Récupérer tous les albums de l'artiste sélectionné
	artist_albums=$(get_artist_albums "$selected_id_artist" "$access_token")

	# Afficher les albums de l'artiste
	selected_album=$(display_artist_albums "$artist_albums")
	if [ -z "$selected_album" ]; then
		echo "Aucun album sélectionné."
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
