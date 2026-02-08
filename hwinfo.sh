#!/usr/bin/env bash
#
# hwinfo.sh — Pretty system hardware info
#

# ---------------------------------------------------------------------------
# Colors & constants
# ---------------------------------------------------------------------------
BOX_WIDTH=56

if [[ -n "$NO_COLOR" ]] || [[ ! -t 1 ]]; then
    BOLD="" RESET="" DIM=""
    CYAN="" BCYAN="" WHITE="" BWHITE="" GREEN="" RED="" BYELLOW=""
else
    BOLD=$'\e[1m'   RESET=$'\e[0m'  DIM=$'\e[2m'
    CYAN=$'\e[36m'  BCYAN=$'\e[1;36m'
    WHITE=$'\e[37m' BWHITE=$'\e[1;37m'
    GREEN=$'\e[32m' RED=$'\e[31m'
    BYELLOW=$'\e[1;33m'
fi

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

cmd_exists() { command -v "$1" &>/dev/null; }

safe_read() {
    local file="$1"
    if [[ -r "$file" ]]; then
        cat "$file" 2>/dev/null | sed 's/[[:space:]]*$//'
    fi
}

# Strip ANSI escape sequences to get visible length
strip_ansi() {
    printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

visible_len() {
    local stripped
    stripped=$(strip_ansi "$1")
    printf '%s' "$stripped" | wc -m
}

# Print the top banner with double-line box
print_banner() {
    local title="$1" subtitle="$2"
    local inner=$((BOX_WIDTH - 2))

    # Top border
    printf "  ${BCYAN}╔"
    printf '═%.0s' $(seq 1 "$inner")
    printf "╗${RESET}\n"

    # Title line — center it
    local tlen=${#title}
    local pad=$(( (inner - tlen) / 2 ))
    local rpad=$(( inner - tlen - pad ))
    printf "  ${BCYAN}║${RESET}"
    printf '%*s' "$pad" ''
    printf "${BWHITE}%s${RESET}" "$title"
    printf '%*s' "$rpad" ''
    printf "${BCYAN}║${RESET}\n"

    # Subtitle line
    local slen=${#subtitle}
    pad=$(( (inner - slen) / 2 ))
    rpad=$(( inner - slen - pad ))
    printf "  ${BCYAN}║${RESET}"
    printf '%*s' "$pad" ''
    printf "${DIM}%s${RESET}" "$subtitle"
    printf '%*s' "$rpad" ''
    printf "${BCYAN}║${RESET}\n"

    # Bottom border
    printf "  ${BCYAN}╚"
    printf '═%.0s' $(seq 1 "$inner")
    printf "╝${RESET}\n"
}

# Section start: ┌─── Title ───...─┐
print_section_start() {
    local title="$1"
    local inner=$((BOX_WIDTH - 2))
    local prefix="─── ${BYELLOW}${title}${RESET}${CYAN} "
    local prefix_visible="─── ${title} "
    local prefix_vlen=${#prefix_visible}
    local dashes=$((inner - prefix_vlen))

    printf "\n  ${CYAN}┌%s" "─── "
    printf "${BYELLOW}%s${RESET}${CYAN} " "$title"
    printf '─%.0s' $(seq 1 "$dashes")
    printf "┐${RESET}\n"
}

# Section end: └───...─┘
print_section_end() {
    local inner=$((BOX_WIDTH - 2))
    printf "  ${CYAN}└"
    printf '─%.0s' $(seq 1 "$inner")
    printf "┘${RESET}\n"
}

# Print a label: value row, right-padded so │ borders align
# Label is padded to LABEL_WIDTH visible chars for column alignment
LABEL_WIDTH=14
print_row() {
    local label="$1" value="$2"
    local inner=$((BOX_WIDTH - 2))
    local label_pad=$((LABEL_WIDTH - ${#label}))
    (( label_pad < 1 )) && label_pad=1
    local content
    content=$(printf "  ${BWHITE}%-s${RESET}%*s${GREEN}%s${RESET}" "$label" "$label_pad" '' "$value")
    local vlen
    vlen=$(visible_len "$content")
    local rpad=$((inner - vlen))
    (( rpad < 0 )) && rpad=0

    printf "  ${CYAN}│${RESET}%s%*s${CYAN}│${RESET}\n" "$content" "$rpad" ''
}

# Print a plain (single-string) row
print_row_plain() {
    local text="$1" color="${2:-$GREEN}"
    local inner=$((BOX_WIDTH - 2))
    local content="  ${color}${text}${RESET}"
    local vlen
    vlen=$(visible_len "$content")
    local rpad=$((inner - vlen))
    (( rpad < 0 )) && rpad=0

    printf "  ${CYAN}│${RESET}%s%*s${CYAN}│${RESET}\n" "$content" "$rpad" ''
}

# ---------------------------------------------------------------------------
# Gather functions
# ---------------------------------------------------------------------------

gather_cpu() {
    print_section_start "CPU"

    local model="" cores="" threads="" max_mhz="" l3_cache=""

    if cmd_exists lscpu; then
        model=$(lscpu | awk -F: '/^Model name/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')
        cores=$(lscpu | awk -F: '/^Core\(s\) per socket/ {gsub(/^[ \t]+/,"",$2); cores=$2}
                         /^Socket\(s\)/             {gsub(/^[ \t]+/,"",$2); socks=$2}
                         END {if(cores&&socks) print cores*socks; else print cores}')
        threads=$(lscpu | awk -F: '/^CPU\(s\)/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')
        max_mhz=$(lscpu | awk -F: '/^CPU max MHz/ {gsub(/^[ \t]+/,"",$2); printf "%.0f", $2; exit}')
        l3_cache=$(lscpu | awk -F: '/^L3 cache/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')
    fi

    # Fallback to /proc/cpuinfo
    if [[ -z "$model" ]] && [[ -r /proc/cpuinfo ]]; then
        model=$(awk -F: '/^model name/ {gsub(/^[ \t]+/,"",$2); print $2; exit}' /proc/cpuinfo)
        threads=$(grep -c '^processor' /proc/cpuinfo)
    fi

    # Clean up trademark symbols
    model=$(printf '%s' "$model" | sed 's/(R)//g; s/(TM)//g; s/  */ /g')

    print_row "Model:" "${model:-N/A}"
    print_row "Cores:" "${cores:-N/A}"
    print_row "Threads:" "${threads:-N/A}"
    [[ -n "$max_mhz" ]] && print_row "Max Clock:" "${max_mhz} MHz"
    [[ -n "$l3_cache" ]] && print_row "L3 Cache:" "${l3_cache}"

    print_section_end
}

gather_memory() {
    print_section_start "Memory"

    local total="" avail="" swap=""

    if cmd_exists free; then
        total=$(free -h | awk '/^Mem:/ {print $2}')
        avail=$(free -h | awk '/^Mem:/ {print $7}')
        swap=$(free -h  | awk '/^Swap:/ {print $2}')
    elif [[ -r /proc/meminfo ]]; then
        local kt ka ks
        kt=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
        ka=$(awk '/^MemAvailable/ {print $2}' /proc/meminfo)
        ks=$(awk '/^SwapTotal/ {print $2}' /proc/meminfo)
        total=$(awk "BEGIN {printf \"%.1f GiB\", $kt/1048576}")
        avail=$(awk "BEGIN {printf \"%.1f GiB\", $ka/1048576}")
        swap=$(awk "BEGIN {printf \"%.1f GiB\", $ks/1048576}")
    fi

    print_row "Total:" "${total:-N/A}"
    print_row "Available:" "${avail:-N/A}"
    print_row "Swap:" "${swap:-N/A}"

    print_section_end
}

gather_storage() {
    print_section_start "Storage"

    local found=0

    if cmd_exists lsblk; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local name size type rota tran model
            read -r name size type rota tran model <<<"$line"

            # Skip virtual devices
            [[ "$name" == loop* || "$name" == zram* ]] && continue
            [[ "$type" != "disk" ]] && continue

            # Classify
            local kind
            if [[ "$tran" == "nvme" ]]; then
                kind="NVMe SSD"
            elif [[ "$rota" == "0" ]]; then
                kind="SATA SSD"
            elif [[ "$rota" == "1" ]]; then
                kind="HDD"
            else
                kind="Disk"
            fi

            print_row_plain "$(printf '%-12s %-6s %s' "$name" "$size" "$kind")"
            if [[ -n "$model" ]]; then
                print_row_plain "$(printf '             %s' "$model")" "$DIM"
            fi
            found=1
        done < <(lsblk -dn -o NAME,SIZE,TYPE,ROTA,TRAN,MODEL 2>/dev/null)
    fi

    if (( found == 0 )); then
        print_row_plain "No block devices found" "$RED"
    fi

    print_section_end
}

gather_motherboard() {
    print_section_start "Motherboard"

    local vendor="" board="" bios_vendor="" bios_ver=""
    local dmi="/sys/class/dmi/id"

    if [[ -d "$dmi" ]]; then
        vendor=$(safe_read "$dmi/board_vendor")
        board=$(safe_read "$dmi/board_name")
        bios_vendor=$(safe_read "$dmi/bios_vendor")
        bios_ver=$(safe_read "$dmi/bios_version")
    fi

    # Fallback to dmidecode
    if [[ -z "$vendor" ]] && cmd_exists dmidecode; then
        local dmi_out
        dmi_out=$(dmidecode -t baseboard 2>/dev/null)
        if [[ -n "$dmi_out" ]]; then
            vendor=$(printf '%s' "$dmi_out" | awk -F: '/Manufacturer/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')
            board=$(printf '%s' "$dmi_out" | awk -F: '/Product Name/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')
        fi
    fi

    if [[ -n "$vendor" || -n "$board" ]]; then
        print_row "Vendor:" "${vendor:-N/A}"
        print_row "Model:" "${board:-N/A}"
        if [[ -n "$bios_vendor" ]]; then
            local bios_str="$bios_vendor"
            [[ -n "$bios_ver" ]] && bios_str="$bios_vendor v$bios_ver"
            print_row "BIOS:" "$bios_str"
        fi
    else
        print_row_plain "Not available (container or VM)" "$DIM"
    fi

    print_section_end
}

gather_gpu() {
    print_section_start "GPU"

    local found=0

    if cmd_exists lspci; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            # Strip PCI address and controller type prefix
            local name
            name=$(printf '%s' "$line" | sed 's/^[^ ]* //; s/.*: //')
            # Clean common vendor prefixes
            name=$(printf '%s' "$name" | sed '
                s/NVIDIA Corporation //
                s/Advanced Micro Devices, Inc\. \[AMD\/ATI\] //
                s/Intel Corporation //
            ')
            print_row_plain "$name"
            found=1
        done < <(lspci 2>/dev/null | grep -iE 'VGA|3D|Display')
    fi

    if (( found == 0 )); then
        print_row_plain "No GPU detected" "$DIM"
    fi

    print_section_end
}

gather_network() {
    print_section_start "Network"

    local found=0

    for iface_path in /sys/class/net/*; do
        local iface
        iface=$(basename "$iface_path")
        [[ "$iface" == "lo" ]] && continue

        local state mac speed_raw speed_str
        state=$(safe_read "$iface_path/operstate")
        mac=$(safe_read "$iface_path/address")
        state=${state:-unknown}

        if [[ "$state" == "up" ]]; then
            speed_raw=$(safe_read "$iface_path/speed" 2>/dev/null)
            if [[ -n "$speed_raw" ]] && (( speed_raw > 0 )) 2>/dev/null; then
                if (( speed_raw >= 1000 )); then
                    speed_str="$(awk "BEGIN {printf \"%.0f\", $speed_raw/1000}") Gb/s"
                else
                    speed_str="${speed_raw} Mb/s"
                fi
            else
                speed_str="--"
            fi
            local state_display
            state_display=$(printf '%s' "UP" | tr '[:lower:]' '[:upper:]')
        else
            speed_str="--"
            local state_display="DOWN"
        fi

        local row
        row=$(printf '%-14s %-5s %-8s %s' "$iface" "$state_display" "$speed_str" "${mac:-N/A}")
        print_row_plain "$row"
        found=1
    done

    if (( found == 0 )); then
        print_row_plain "No network interfaces found" "$DIM"
    fi

    print_section_end
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    local hostname kernel
    hostname=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "unknown")
    kernel=$(uname -r 2>/dev/null || echo "unknown")

    echo
    print_banner "SYSTEM HARDWARE INFO" "$hostname / Linux $kernel"
    gather_cpu
    gather_memory
    gather_storage
    gather_motherboard
    gather_gpu
    gather_network
    echo
}

main
