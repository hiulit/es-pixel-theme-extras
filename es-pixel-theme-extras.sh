#!/usr/bin/env bash
# install-es-pixel-theme-extras.sh

# Globals #############################################

user="$SUDO_USER"
[[ -z "$user" ]] && user="$(id -un)"

home="$(find /home -type d -name RetroPie -print -quit 2> /dev/null)"
home="${home%/RetroPie}"

readonly RP_DIR="$home/RetroPie"
readonly RP_CONFIG_DIR="/opt/retropie/configs"
readonly ES_THEMES_DIR="/etc/emulationstation/themes"
readonly SPLASH_LIST="/etc/splashscreen.list"
readonly TMP=".tmp"


# Variables ############################################

readonly RP_ICONS_DIR="$RP_DIR/retropiemenu/icons"
readonly RP_BACKUP_ICONS_DIR="$RP_ICONS_DIR/rp-icons-backup"

# Defaults
readonly DEFAULT_THEME="pixel"

# Global variables
THEME="$DEFAULT_THEME"
readonly THEME_ICONS_DIR="$ES_THEMES_DIR/$THEME/retropie/icons"
readonly GIT_THEME_LAUNCHING_IMAGES="https://github.com/ehettervik/es-runcommand-splash.git"
readonly TMP_LAUNCHING_IMAGES_DIR="$TMP/$THEME-launching-images"


# Functions ############################################


function is_sudo() {
    [[ "$(id -u)" -eq 0 ]]
}


function usage() {
    echo "USAGE: 'sudo $0 --install OR --uninstall'"
    exit 0
}


function check_rp_icons_dir() {
    [[ ! -d "$RP_ICONS_DIR" ]] && mkdir -p "$RP_ICONS_DIR" && chown -R "$user":"$user" "$RP_ICONS_DIR"
}


function check_theme_icons_dir() {
    if [[ ! -d "$THEME_ICONS_DIR" ]]; then
        echo "ERROR: '$THEME' theme doesn't have any icons." >&2
        return 1
    else
        return 0
    fi
}


function check_theme() {
    local theme="$1"
    [[ -z "$theme" ]] && echo "ERROR: '${FUNCNAME[0]}' needs a theme as an argument!" >&2 && exit 1
    if [[ ! -d "$ES_THEMES_DIR/$theme" ]]; then
        echo "ERROR: '$theme' theme theme doesn't exists!" >&2
        echo "Check '$ES_THEMES_DIR' to see all the available themes." >&2
        exit 1
    fi
}


function copy_all_files() {
    local from_dir="$1"
    local to_dir="$2"
    [[ -z "$from_dir" || -z "$to_dir" ]] && echo "ERROR: '${FUNCNAME[0]}' needs a 'from' directory and a 'to' directory as arguments!" >&2 && exit 1
    local file
    for file in "$from_dir/"*; do
        if [[ -f "$file" ]]; then
            cp "$file" "$to_dir"
            chown -R "$user":"$user" "$file"
        fi
    done
}


function remove_all_files() {
    local from_dir="$1"
    [[ -z "$from_dir" ]] && echo "ERROR: '${FUNCNAME[0]}' needs a 'from' directory as  an argument!" >&2 && exit 1
    for file in "$from_dir/"*; do
        if [[ -f "$file" ]]; then
            rm -rf "$file"
        fi
    done
}


function backup_icons() {
    if [[ ! -d "$RP_BACKUP_ICONS_DIR" ]]; then
        mkdir -p "$RP_BACKUP_ICONS_DIR" && chown -R "$user":"$user" "$RP_BACKUP_ICONS_DIR"
        copy_all_files "$RP_ICONS_DIR" "$RP_BACKUP_ICONS_DIR"
    fi
}


function choose_splashscreen() {
    local splashscreen
    local splashscreens
    local options=()
    local option

    splashscreens=($(find "$ES_THEMES_DIR/$THEME" -maxdepth 1 -type f -name "*splash*"))
    
    if [[ "${#splashscreens[@]}" -gt 0 ]]; then
        echo "Choose a splashscreen to install:"
        for splashscreen in "${splashscreens[@]}"; do
            if [[ -f "$splashscreen" ]]; then
                options+=("$(basename "$splashscreen")")
            fi
        done
        select option in "${options[@]}"; do
            if [[ -n "$option" ]]; then
                add_splashscreen "$ES_THEMES_DIR/$THEME/$option"
                break
            else
                echo "Invalid option. Choose a number between 1 and ${#options[@]}."
            fi
        done

    else
        add_splashscreen "$ES_THEMES_DIR/$THEME/$splashscreens"
    fi
}


function add_splashscreen() {
    local splashscreen="$1"
    [[ -z "$splashscreen" ]] && echo "ERROR: '${FUNCNAME[0]}' needs a splashscreen path as an argument!" >&2 && exit 1
    if [[ ! -f "$SPLASH_LIST" ]]; then
        touch "$SPLASH_LIST" && chown -R "$user":"$user" "$SPLASH_LIST"
    fi
    echo "$splashscreen" > "$SPLASH_LIST"
}


function remove_splashscreen() {
    echo "" > "$SPLASH_LIST"
}


function install_icons() {
    echo "> Installing '$THEME' theme icons ..."
    check_rp_icons_dir
    if check_theme_icons_dir; then
        backup_icons
        remove_all_files "$RP_ICONS_DIR"
        copy_all_files "$THEME_ICONS_DIR" "$RP_ICONS_DIR"
    else
        return 1
    fi
}


function uninstall_icons() {
    echo "> Uninstalling '$THEME' theme icons ..."
    if [[ -d "$RP_BACKUP_ICONS_DIR" ]]; then
        remove_all_files "$RP_ICONS_DIR"
        copy_all_files "$RP_BACKUP_ICONS_DIR" "$RP_ICONS_DIR"
        rm -rf "$RP_BACKUP_ICONS_DIR"
    else
        echo "Seems like '$THEME' theme icons are not installed."
        return 1
    fi

}


function install_launching_images() {
    echo "> Installing '$THEME' theme launching images ..."
    [[ ! -d "$TMP" ]] && mkdir -p "$TMP" && chown -R "$user":"$user" "$TMP"
    if [[ ! -d "$TMP_LAUNCHING_IMAGES_DIR" ]]; then
        echo "> Dowloading '$THEME' launching images ..."
        git clone "$GIT_THEME_LAUNCHING_IMAGES" "$TMP_LAUNCHING_IMAGES_DIR"
    fi
    local from_dir
    local to_dir
    local launching_image
    for from_dir in "$TMP_LAUNCHING_IMAGES_DIR/"*; do
        if [[ -d "$from_dir" ]]; then
            to_dir="$RP_CONFIG_DIR/$(basename "$from_dir")"
            if [[ -d "$to_dir" ]]; then
                launching_image=$(find "$from_dir" -type f -name 'launching.*' -print -quit 2> /dev/null)
                if [[ -f "$launching_image" ]]; then
                    cp "$launching_image" "$to_dir/$(basename "$launching_image")"
                fi
            fi
        fi
    done
}


function uninstall_launching_images() {
    echo "> Uninstalling '$THEME' theme launching images ..."
    if [[ -d "$TMP_LAUNCHING_IMAGES_DIR" ]]; then
        rm -rf "$TMP_LAUNCHING_IMAGES_DIR"
        local dir
        local launching_image
        for dir in "$RP_CONFIG_DIR/"*; do
            if [[ -d "$dir" ]]; then
                launching_image=$(find "$dir" -type f -name 'launching.*' -print -quit 2> /dev/null)
                if [[ -f "$launching_image" ]]; then
                    rm "$launching_image"
                fi
            fi
        done
    else
        echo "Seems like '$THEME' theme launching images are not installed."
        return 1
    fi
}


function install_splashscreen() {
    echo "> Installing '$THEME' theme launching images ..."
    choose_splashscreen
}


function uninstall_splashscreen() {
    echo "> Uninstalling '$THEME' theme launching images ..."
    remove_splashscreen
}


function get_options() {
    [[ -z "$1" ]] && usage

    while [[ -n "$1" ]]; do
        case "$1" in
            --install)
                if install_icons; then
                    echo "'$THEME' theme icons installed successfully!"
                else
                    echo "ERROR: Couldn't install '$THEME' theme icons." >&2
                fi

                if install_launching_images; then
                    echo "'$THEME' theme launching images installed successfully!"
                else
                    echo "ERROR: Couldn't install '$THEME' theme launching images." >&2
                fi

                if install_splashscreen; then
                    echo "'$THEME' theme splashscreen installed successfully!"
                else
                    echo "ERROR: Couldn't install '$THEME' theme splashscreen." >&2
                fi
                ;;
            --uninstall)
                if uninstall_icons; then
                    echo "'$THEME' theme icons uninstalled successfully!"
                else
                    echo "ERROR: Couldn't uninstall '$THEME' theme icons." >&2
                fi

                if uninstall_launching_images; then
                    echo "'$THEME' theme launching images uninstalled successfully!"
                else
                    echo "ERROR: Couldn't uninstall '$THEME' theme launching images." >&2
                fi


                if uninstall_splashscreen; then
                    echo "'$THEME' theme splashscreen uninstalled successfully!"
                else
                    echo "ERROR: Couldn't uninstall '$THEME' theme splashscreen." >&2
                fi
                ;;
            *)
                echo "ERROR: Invalid option '$1'." >&2
                echo "Try 'sudo $0 --install OR --uninstall'." >&2
                exit 2
                ;;
        esac
        shift
    done
}


function main() {
    if ! is_sudo; then
        echo "ERROR: '"$0"' must be run under 'sudo'." >&2
        echo "Try 'sudo "$0"'." >&2
        exit 1
    fi

    # [[ -n "$1" ]] && THEME="$1"

    check_theme "$THEME"
    # shift

    get_options "$@"
}


main "$@"
