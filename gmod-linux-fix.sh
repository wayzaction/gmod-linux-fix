#!/bin/bash -e

prompt_user() {
    local prompt="$1"
    local var
    read -p "$prompt" var
    echo "$var"
}

DIRECTORY="$1"
if [ "$#" -ne 1 ]; then
    DIRECTORY=$(prompt_user "Enter Garry's Mod directory (Example: /home/wayz/.local/share/Steam/steamapps/common/GarrysMod): ")
fi

if ! [ -d "$DIRECTORY" ]; then
    echo "No such directory. Try again."
    exit 1
fi

HEAPSIZE=$(prompt_user "How much memory should Garry's Mod allocate in megabytes? (Example: 4096 for 4GB, 8192 for 8GB, 16384 for 16GB, 32678 for 32GB): ")

echo -e "\nBefore continuing, ensure Garry's Mod is on the 64-bit branch\n"
echo -e "Right-click on Garry's Mod in Steam -> Properties -> Betas -> Select 'x86_64 - Chromium + 64-bit binaries'.\nPress Enter to continue."
read -r

echo "> Patching $DIRECTORY!"

echo "> Downloading GModCEFCodecFix... (!!! GModCEFCodecFix will ask you if you want to launch the game. Write "no" !!!)"
CEF_FIX_URL="https://github.com/solsticegamestudios/GModCEFCodecFix/releases/latest/download/GModCEFCodecFix-Linux"
CEF_FIX_PATH="/tmp/GModCEFCodecFix-Linux"

wget -q "$CEF_FIX_URL" -O "$CEF_FIX_PATH"
chmod +x "$CEF_FIX_PATH"

# Ensure a terminal emulator is used to execute the fix (It fucking sucks)
TERMINAL=$(command -v x-terminal-emulator || command -v gnome-terminal || command -v konsole || command -v alacritty || command -v xterm || command -v kitty || command -v terminator || command -v urxvt || command -v xfce4-terminal)
if [ -z "$TERMINAL" ]; then
    echo "No compatible terminal emulator found! Please run GModCEFCodecFix manually:"
    echo "$CEF_FIX_PATH"
    exit 1
fi

$TERMINAL -e "$CEF_FIX_PATH" || {
    echo "Failed to launch terminal emulator. Please run GModCEFCodecFix manually:"
    echo "$CEF_FIX_PATH"
    exit 1
}

# Update valve.rc
VALVE_RC="$DIRECTORY/garrysmod/cfg/valve.rc"
if ! grep -q 'gmod-linux-patcher' "$VALVE_RC"; then
    echo "> Setting mem_max_heapsize and filesystem_max_stdio_read in garrysmod/cfg/valve.rc..."
    echo "// gmod-linux-patcher
mem_min_heapsize 256
mem_max_heapsize $HEAPSIZE
mem_max_heapsize_dedicated $HEAPSIZE
filesystem_max_stdio_read $(ulimit -Hn)
" | cat - "$VALVE_RC" > /tmp/valve.rc && mv /tmp/valve.rc "$VALVE_RC"
fi

HL2_SH="$DIRECTORY/hl2.sh"
if ! grep -q 'gmod-linux-patcher' "$HL2_SH"; then
    echo "> Replacing 'ulimit -n 2048' in hl2.sh with 'ulimit -n $(ulimit -Hn)'..."
    echo "> Adding 'export mesa_glthread=true' to hl2.sh..."
    sed -i "s/ulimit -n 2048/# gmod-linux-patcher\nulimit -n $(ulimit -Hn)\nexport mesa_glthread=true/g" "$HL2_SH"

    echo "> Modifying game arguments..."
    sed -i 's/exec ${GAME_DEBUGGER} "${GAMEROOT}"\/${GAMEEXE} "$@"/# gmod-linux-patcher\n        exec ${GAME_DEBUGGER} "${GAMEROOT}"\/${GAMEEXE} -malloc=system -swapcores -dxlevel 98 -vulkan "$@"/g' "$HL2_SH"
fi

echo "> Done!"
