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
rp_module_help="After installing, ES-X becomes the main frontend. Includes automatic language .ini installation, Theme Browser previews, default ES-X theme, and Skyscraper integration."
rp_module_section="exp"
rp_module_flags="frontend"

rp_module_licence="MIT https://github.com/Aloshi/EmulationStation/blob/master/LICENSE"

# ES-X repository
rp_module_repo="git https://github.com/Renetrox/EmulationStation-X main"

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
    # 2) Configure ES-X using upstream logic
    # ============================================================
    echo "Configuring ES-X..."
    configure_emulationstation

    # ============================================================
    # 2.5) Ensure Skyscraper is installed ONLY if missing
    # ============================================================
    echo "Checking Skyscraper installation..."

    local skyscraper_bin=""
    skyscraper_bin="$(command -v Skyscraper 2>/dev/null)"

    if [[ -z "$skyscraper_bin" ]]; then
        # Fallback paths commonly used by RetroPie/manual installs
        local sky_candidate
        for sky_candidate in \
            "/usr/local/bin/Skyscraper" \
            "/usr/bin/Skyscraper" \
            "$home/RetroPie-Setup/tmp/build/skyscraper/Skyscraper"
        do
            if [[ -x "$sky_candidate" ]]; then
                skyscraper_bin="$sky_candidate"
                break
            fi
        done
    fi

    if [[ -n "$skyscraper_bin" && -x "$skyscraper_bin" ]]; then
        echo "Skyscraper already installed at: $skyscraper_bin"
    else
        echo "Skyscraper not found. Installing via RetroPie-Setup module..."
        rp_callModule "skyscraper"
    fi

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
    # 3) Install language files (.ini)
    # ============================================================
    echo "Installing ES-X language files..."

    local lang_dst="$home/.emulationstation/lang"
    local lang_src=""
    lang_src="$(resolve_dir \
        "$md_build/lang" \
        "$md_inst/lang" \
        "$md_inst/resources/lang" \
    )"

    if [[ -n "$lang_src" && -d "$lang_src" ]]; then
        mkUserDir "$lang_dst"

        if command -v rsync >/dev/null 2>&1; then
            rsync -a --update "$lang_src"/ "$lang_dst"/ 2>/dev/null
        else
            cp -uv "$lang_src"/*.ini "$lang_dst"/ 2>/dev/null
            cp -ru "$lang_src"/. "$lang_dst"/ 2>/dev/null
        fi

        chown -R "$user:$user" "$lang_dst"
        echo "Language files installed at $lang_dst"
    else
        echo "WARNING: No 'lang' folder found for ES-X."
    fi

    # ============================================================
    # 3.2) Install ES-X Skyscraper helper script
    #      Copies to: ~/.emulationstation/scripts/skyscraper-esx.sh
    # ============================================================
    echo "Installing ES-X Skyscraper helper script..."

    local scripts_dir="$home/.emulationstation/scripts"
    local sky_script_src=""
    local sky_script_dst="$scripts_dir/skyscraper-esx.sh"

    sky_script_src="$(resolve_path \
        "$md_build/resources/skyscraper-esx.sh" \
        "$md_inst/resources/skyscraper-esx.sh" \
        "$md_build/skyscraper-esx.sh" \
        "$md_inst/skyscraper-esx.sh" \
    )"

    if [[ -n "$sky_script_src" && -f "$sky_script_src" ]]; then
        mkUserDir "$scripts_dir"
        cp -f "$sky_script_src" "$sky_script_dst"
        chmod 755 "$sky_script_dst"
        chown "$user:$user" "$sky_script_dst"
        echo "Skyscraper helper installed at $sky_script_dst"
    else
        echo "WARNING: No 'skyscraper-esx.sh' script found in ES-X source."
    fi

    # ============================================================
    # 3.3) Install ES-X artwork.xml for Skyscraper
    #      Copies to: ~/.skyscraper/artwork.xml
    #      If one already exists, back it up as artwork.xml.bak
    # ============================================================
    echo "Installing ES-X Skyscraper artwork.xml..."

    local sky_cfg_dir="$home/.skyscraper"
    local artwork_src=""
    local artwork_dst="$sky_cfg_dir/artwork.xml"
    local artwork_bak="$sky_cfg_dir/artwork.xml.bak"

    artwork_src="$(resolve_path \
        "$md_build/resources/artwork.xml" \
        "$md_inst/resources/artwork.xml" \
        "$md_build/artwork.xml" \
        "$md_inst/artwork.xml" \
    )"

    if [[ -n "$artwork_src" && -f "$artwork_src" ]]; then
        mkUserDir "$sky_cfg_dir"

        if [[ -f "$artwork_dst" ]]; then
            echo "Existing artwork.xml found — backing up to artwork.xml.bak"
            cp -f "$artwork_dst" "$artwork_bak"
        fi

        cp -f "$artwork_src" "$artwork_dst"
        chmod 644 "$artwork_dst"
        [[ -f "$artwork_bak" ]] && chmod 644 "$artwork_bak"
        chown "$user:$user" "$artwork_dst"
        [[ -f "$artwork_bak" ]] && chown "$user:$user" "$artwork_bak"

        echo "Skyscraper artwork.xml installed at $artwork_dst"
    else
        echo "WARNING: No 'artwork.xml' found in ES-X source."
    fi

    # ============================================================
    # 3.25) Install ES-X Theme Browser previews (PNG + INI)
    #      Copies to: ~/.emulationstation/esx/theme-previews
    #      - INI files: overwrite/update to keep catalog current
    #      - Other files (png, folders): merge without deleting user extras
    # ============================================================
    echo "Installing ES-X theme previews (Theme Browser)..."

    local esx_root="$home/.emulationstation/esx"
    local previews_dst="$esx_root/theme-previews"
    local previews_src=""
    previews_src="$(resolve_dir \
        "$md_build/esx/theme-previews" \
        "$md_inst/esx/theme-previews" \
        "$md_inst/resources/esx/theme-previews" \
    )"

    if [[ -n "$previews_src" && -d "$previews_src" ]]; then
        mkUserDir "$previews_dst"

        if compgen -G "$previews_src"/*.ini > /dev/null; then
            cp -uv "$previews_src"/*.ini "$previews_dst"/ 2>/dev/null
        fi

        if command -v rsync >/dev/null 2>&1; then
            rsync -a --ignore-existing --exclude="*.ini" "$previews_src"/ "$previews_dst"/ 2>/dev/null
        else
            cp -ruv "$previews_src"/. "$previews_dst"/ 2>/dev/null
        fi

        find "$previews_dst" -type f -exec chmod 644 {} \; 2>/dev/null
        find "$previews_dst" -type d -exec chmod 755 {} \; 2>/dev/null

        chown -R "$user:$user" "$esx_root"
        echo "Theme previews installed/updated at $previews_dst"
    else
        echo "WARNING: No 'esx/theme-previews' folder found in ES-X source."
    fi

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

    chown -R "$user:$user" "$music_dir"

    # ============================================================
    # 4) Install / update ES-X themes
    # ============================================================
    echo "Installing ES-X themes..."
    local themes_dir="$home/.emulationstation/themes"
    mkUserDir "$themes_dir"

    install_esx_theme() {
        local repo="$1"
        local folder="$2"
        local target="$themes_dir/$folder"

        if [[ -d "$target/.git" ]]; then
            echo "Checking updates for theme: $folder"
            git -C "$target" fetch --quiet

            local local_rev remote_rev
            local_rev="$(git -C "$target" rev-parse HEAD 2>/dev/null)"
            remote_rev="$(git -C "$target" rev-parse @{u} 2>/dev/null)"

            if [[ -n "$local_rev" && -n "$remote_rev" && "$local_rev" != "$remote_rev" ]]; then
                echo "Updating theme: $folder"
                git -C "$target" pull --ff-only
            else
                echo "Theme already up to date: $folder"
            fi

        elif [[ -d "$target" ]]; then
            echo "Theme folder exists but is not a git repository: $folder — leaving untouched."

        else
            echo "Cloning theme: $folder"
            git clone --depth 1 "$repo" "$target"
            chown -R "$user:$user" "$target"
        fi
    }

    install_esx_theme "https://github.com/Renetrox/Alekfull-nx-retropie" "Alekfull-nx-retropie"

    echo "Themes installed."

    # ============================================================
    # 5) Apply default theme ONLY on first install
    # ============================================================
    local es_settings="$home/.emulationstation/es_settings.cfg"

    if [[ ! -f "$es_settings" ]] || ! grep -q "<string name=\"ThemeSet\"" "$es_settings"; then
        echo "Applying default ES-X theme: Alekfull-nx-retropie"

        mkUserDir "$(dirname "$es_settings")"
        touch "$es_settings"

        if grep -q "<string name=\"ThemeSet\"" "$es_settings"; then
            sed -i 's|<string name="ThemeSet".*|<string name="ThemeSet" value="Alekfull-nx-retropie" />|' "$es_settings"
        else
            echo '<string name="ThemeSet" value="Alekfull-nx-retropie" />' >> "$es_settings"
        fi

        chown "$user:$user" "$es_settings"
    else
        echo "Theme already configured by user — not changing."
    fi

    echo "ES-X configuration complete."
}

function remove_emulationstation-es-x() { remove_emulationstation; }
function gui_emulationstation-es-x()    { gui_emulationstation; }
