#!/bin/bash
#
# CARINA MissionLab - Device Detection Utility
# Detects connected serial devices, USB devices, and known microcontrollers
#

# CARINA Color Palette
CARINA_CYAN='\033[38;2;61;232;255m'
CARINA_MAGENTA='\033[38;2;177;76;255m'
CARINA_BLUE='\033[38;2;31;162;255m'
CARINA_TEXT='\033[38;2;230;236;255m'
CARINA_MUTED='\033[38;2;154;163;199m'
NC='\033[0m'

# Known vendor IDs and their names
declare -A VENDOR_NAMES=(
    ["0403"]="FTDI"
    ["10c4"]="Silicon Labs"
    ["067b"]="Prolific"
    ["1a86"]="WCH (CH340)"
    ["2341"]="Arduino"
    ["2a03"]="Arduino LLC"
    ["0483"]="STMicroelectronics"
    ["2e8a"]="Raspberry Pi"
    ["16c0"]="Teensy/PJRC"
    ["303a"]="Espressif"
    ["1366"]="Segger"
    ["1d50"]="OpenMoko"
    ["03eb"]="Atmel/Microchip"
)

# Known product IDs for specific boards
declare -A PRODUCT_NAMES=(
    ["2341:0043"]="Arduino Uno"
    ["2341:0001"]="Arduino Uno"
    ["2341:0010"]="Arduino Mega 2560"
    ["2341:0042"]="Arduino Mega 2560"
    ["2341:003d"]="Arduino Due"
    ["2341:8036"]="Arduino Leonardo"
    ["2341:8037"]="Arduino Micro"
    ["2a03:0043"]="Arduino Uno (clone)"
    ["0483:3748"]="ST-Link V2"
    ["0483:374b"]="ST-Link V2-1"
    ["0483:df11"]="STM32 DFU Bootloader"
    ["2e8a:0003"]="Raspberry Pi Pico"
    ["2e8a:000a"]="Raspberry Pi Pico W"
    ["10c4:ea60"]="CP210x USB-Serial"
    ["1a86:7523"]="CH340 USB-Serial"
    ["0403:6001"]="FTDI FT232R"
    ["0403:6010"]="FTDI FT2232"
    ["0403:6014"]="FTDI FT232H"
    ["16c0:0483"]="Teensy"
    ["16c0:0478"]="Teensy (bootloader)"
    ["303a:1001"]="ESP32-S2"
    ["303a:0002"]="ESP32-S3"
)

detect_serial_ports() {
    echo -e "${CARINA_CYAN}Serial Ports${NC}"
    echo -e "${CARINA_MUTED}------------${NC}"
    
    local found=0
    
    # Check /dev/ttyUSB* devices
    for port in /dev/ttyUSB*; do
        if [[ -e "$port" ]]; then
            found=1
            local info=""
            
            # Try to get device info from udevadm
            local vendor=$(udevadm info -q property -n "$port" 2>/dev/null | grep "ID_VENDOR_ID=" | cut -d= -f2)
            local product=$(udevadm info -q property -n "$port" 2>/dev/null | grep "ID_MODEL_ID=" | cut -d= -f2)
            local model=$(udevadm info -q property -n "$port" 2>/dev/null | grep "ID_MODEL=" | cut -d= -f2)
            
            if [[ -n "$vendor" ]]; then
                local key="${vendor}:${product}"
                if [[ -n "${PRODUCT_NAMES[$key]}" ]]; then
                    info="${PRODUCT_NAMES[$key]}"
                elif [[ -n "${VENDOR_NAMES[$vendor]}" ]]; then
                    info="${VENDOR_NAMES[$vendor]}"
                    [[ -n "$model" ]] && info="$info ($model)"
                else
                    info="$model"
                fi
            fi
            
            echo -e "  ${CARINA_TEXT}$port${NC} ${CARINA_MUTED}${info}${NC}"
        fi
    done
    
    # Check /dev/ttyACM* devices (CDC ACM)
    for port in /dev/ttyACM*; do
        if [[ -e "$port" ]]; then
            found=1
            local info=""
            
            local vendor=$(udevadm info -q property -n "$port" 2>/dev/null | grep "ID_VENDOR_ID=" | cut -d= -f2)
            local product=$(udevadm info -q property -n "$port" 2>/dev/null | grep "ID_MODEL_ID=" | cut -d= -f2)
            local model=$(udevadm info -q property -n "$port" 2>/dev/null | grep "ID_MODEL=" | cut -d= -f2)
            
            if [[ -n "$vendor" ]]; then
                local key="${vendor}:${product}"
                if [[ -n "${PRODUCT_NAMES[$key]}" ]]; then
                    info="${PRODUCT_NAMES[$key]}"
                elif [[ -n "${VENDOR_NAMES[$vendor]}" ]]; then
                    info="${VENDOR_NAMES[$vendor]}"
                    [[ -n "$model" ]] && info="$info ($model)"
                else
                    info="$model"
                fi
            fi
            
            echo -e "  ${CARINA_TEXT}$port${NC} ${CARINA_MUTED}${info}${NC}"
        fi
    done
    
    if [[ $found -eq 0 ]]; then
        echo -e "  ${CARINA_MUTED}No serial ports detected${NC}"
    fi
    
    echo ""
}

detect_usb_devices() {
    echo -e "${CARINA_CYAN}USB Devices (Development)${NC}"
    echo -e "${CARINA_MUTED}-------------------------${NC}"
    
    local found=0
    
    # Use lsusb to find devices
    if command -v lsusb &>/dev/null; then
        while IFS= read -r line; do
            # Extract vendor:product ID
            local vid_pid=$(echo "$line" | grep -oP 'ID \K[0-9a-f]{4}:[0-9a-f]{4}')
            local vid=$(echo "$vid_pid" | cut -d: -f1)
            local pid=$(echo "$vid_pid" | cut -d: -f2)
            
            # Check if this is a known development device
            if [[ -n "${VENDOR_NAMES[$vid]}" ]] || [[ -n "${PRODUCT_NAMES[$vid_pid]}" ]]; then
                found=1
                local name=""
                
                if [[ -n "${PRODUCT_NAMES[$vid_pid]}" ]]; then
                    name="${PRODUCT_NAMES[$vid_pid]}"
                else
                    name="${VENDOR_NAMES[$vid]} device"
                fi
                
                echo -e "  ${CARINA_TEXT}$vid_pid${NC} ${CARINA_MUTED}$name${NC}"
            fi
        done < <(lsusb 2>/dev/null)
    fi
    
    if [[ $found -eq 0 ]]; then
        echo -e "  ${CARINA_MUTED}No known development devices detected${NC}"
    fi
    
    echo ""
}

detect_cameras() {
    echo -e "${CARINA_CYAN}Video Devices${NC}"
    echo -e "${CARINA_MUTED}-------------${NC}"
    
    local found=0
    
    for video in /dev/video*; do
        if [[ -e "$video" ]]; then
            found=1
            local info=""
            
            # Try to get device name
            if command -v v4l2-ctl &>/dev/null; then
                info=$(v4l2-ctl -d "$video" --info 2>/dev/null | grep "Card type" | cut -d: -f2 | xargs)
            fi
            
            if [[ -z "$info" ]]; then
                info="Video capture device"
            fi
            
            echo -e "  ${CARINA_TEXT}$video${NC} ${CARINA_MUTED}$info${NC}"
        fi
    done
    
    if [[ $found -eq 0 ]]; then
        echo -e "  ${CARINA_MUTED}No video devices detected${NC}"
    fi
    
    echo ""
}

detect_gpio() {
    echo -e "${CARINA_CYAN}GPIO/Hardware Interfaces${NC}"
    echo -e "${CARINA_MUTED}------------------------${NC}"
    
    local found=0
    
    # Check for GPIO chips
    for gpio in /dev/gpiochip*; do
        if [[ -e "$gpio" ]]; then
            found=1
            echo -e "  ${CARINA_TEXT}$gpio${NC} ${CARINA_MUTED}GPIO controller${NC}"
        fi
    done
    
    # Check for I2C buses
    for i2c in /dev/i2c-*; do
        if [[ -e "$i2c" ]]; then
            found=1
            echo -e "  ${CARINA_TEXT}$i2c${NC} ${CARINA_MUTED}I2C bus${NC}"
        fi
    done
    
    # Check for SPI devices
    for spi in /dev/spidev*; do
        if [[ -e "$spi" ]]; then
            found=1
            echo -e "  ${CARINA_TEXT}$spi${NC} ${CARINA_MUTED}SPI device${NC}"
        fi
    done
    
    if [[ $found -eq 0 ]]; then
        echo -e "  ${CARINA_MUTED}No GPIO/hardware interfaces detected${NC}"
    fi
    
    echo ""
}

main() {
    echo -e "${CARINA_CYAN}CARINA MissionLab - Device Detection${NC}"
    echo -e "${CARINA_MUTED}=====================================${NC}"
    echo ""
    
    detect_serial_ports
    detect_usb_devices
    detect_cameras
    detect_gpio
    
    echo -e "${CARINA_MUTED}Scan complete.${NC}"
}

main "$@"
