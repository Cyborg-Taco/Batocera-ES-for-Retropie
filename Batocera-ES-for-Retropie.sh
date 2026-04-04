#!/usr/bin/env bash

# ============================================================
#  EmulationStation-X (ES-X) for RetroPie
#  Experimental fork with .ini language support + theme system
#  by Renetrox
#
#  This module REPLACES the standard EmulationStation.
#  Installs ES-X + its language files + default ES-X themes.
#  Also installs ES-X theme browser previews (esx/theme-previews).
# ============================================================

rp_module_id="batocera-es-for-retropie"
rp_module_desc="EmulationStation-X (ES-X) - Experimental fork with .ini language and theme enhancements (replaces standard EmulationStation)"
rp_module_help="After installing, Batocera ES becomes the main frontend."
rp_module_section="exp"
rp_module_flags="frontend"

rp_module_licence="MIT https://github.com/batocera-linux/batocera-emulationstation/blob/master/LICENSE.md"

# ES-X repository
rp_module_repo="git https://github.com/Cyborg-Taco/Batocera-ES-for-Retropie main"

# ------------------------------------------------------------
# Link to base EmulationStation build system
# ------------------------------------------------------------
function _update_hook_emulationstation-es-x() { _update_hook_emulationstation; }

# ES-X needs SDL2_mixer headers
function depends_emulationstation-es-x() {
    depends_emulationstation
    getDepends libsdl2-mixer-dev
}

function sources_emulationstation-es-x()      { sources_emulationstation; }
function build_emulationstation-es-x()        { build_emulationstation; }
function install_emulationstation-es-x()      { install_emulationstation; }

# ------------------------------------------------------------

function configure_emulationstation-es-x() {

    # ============================================================
    # 1) Remove standard EmulationStation (if present)
    # ============================================================
    echo "Removing original EmulationStation (if installed)..."
    rp_callModule "emulationstation" remove

    # ============================================================
    # 2) Configure Batocera ES using upstream logic
    # ============================================================
    echo "Configuring Batocera ES..."
    configure_emulationstation
    
    # ============================================================
    # Helper: resolve first existing directory or file
    # ============================================================
    resolve_path() {
        local p
        for p in "$@"; do
            [[ -e "$p" ]] && { echo "$p"; return 0; }
        done
        return 1
    }

    resolve_dir() {
        local p
        for p in "$@"; do
            [[ -d "$p" ]] && { echo "$p"; return 0; }
        done
        return 1
    }

    # ============================================================
    # 3.5) Ensure RetroPie music folder exists
    #      If repo has default music, copy ONLY if destination is empty
    # ============================================================
    echo "Ensuring RetroPie music folder exists..."
    local music_dir="$home/RetroPie/music"
    mkUserDir "$music_dir"

    local music_src=""
    music_src="$(resolve_dir \
        "$md_build/music" \
        "$md_inst/music" \
        "$md_inst/resources/music" \
    )"

    if [[ -n "$music_src" && -d "$music_src" ]]; then
        if [[ -z "$(ls -A "$music_dir" 2>/dev/null)" ]]; then
            echo "Copying default music (destination was empty)..."
            cp -ruv "$music_src"/. "$music_dir"/ 2>/dev/null
        else
            echo "Music folder already has files — leaving untouched."
        fi
    else
        echo "Music folder ready at $music_dir (no bundled music found)"
    fi

    chown -R "$user:$user" "$music_dir
    
    echo "Batocera ES configuration complete."
}

function remove_emulationstation-es-x() { remove_emulationstation; }
function gui_emulationstation-es-x()    { gui_emulationstation; }
