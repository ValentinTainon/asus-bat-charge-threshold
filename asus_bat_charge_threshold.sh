#!/usr/bin/bash

# VARS
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RESET_CLR="\e[0m"

BAT_SERVICE_FILE_PATH="/etc/systemd/system/bat-charge-threshold.service"
BAT_DIR_NAMES=("BAT0" "BAT1" "BATT" "BATC")
IS_COMPATIBLE_DEVICE="false"
IS_SERVICE_EXIST="false"

# FUNCTIONS
check_cmd() {
    if [ $? == 0 ]; then
        echo -e "[$GREEN OK $RESET_CLR]"
    else
        echo -e "[$RED ERROR $RESET_CLR]"
    fi
}

### SCRIPT START ###
echo -e "${MAGENTA}ASUS BAT CHARGE THRESHOLD SERVICE $RESET_CLR"

# TEST ROOT
if [ "$(whoami)" != "root" ]; then
    echo -e "[$RED ERROR $RESET_CLR] Non-root user. Please run the script again as root"
    exit 1
fi

# CHECK DEVICE TYPE
if ! hostnamectl chassis | grep -q "laptop"; then
    echo "Laptop not detected, this service is not compatible with this device"
    exit 1
fi

# CHECK HARDWARE VENDOR
if ! hostnamectl | grep -q "Hardware Vendor: ASUS"; then
    echo "Asus hardware vendor not detected, this service is not compatible with this device"
    exit 1
fi

# CHECK IF ASUS BAT CHARGE THRESHOLD SERVICE EXIST
if [ -f "$BAT_SERVICE_FILE_PATH" ]; then
    IS_SERVICE_EXIST="true"
fi

# CREATE/UPDATE BAT CHARGE THRESHOLD SERVICE
for BAT_DIR_NAME in ${BAT_DIR_NAMES[@]}; do
    if [ -d "/sys/class/power_supply/$BAT_DIR_NAME" ] && [ -f "/sys/class/power_supply/$BAT_DIR_NAME/charge_control_end_threshold" ]; then
        IS_COMPATIBLE_DEVICE="true"

        echo -e "The current battery charge threshold is :$CYAN $(cat /sys/class/power_supply/$BAT_DIR_NAME/charge_control_end_threshold)"
        
        echo -ne "${YELLOW}Do you want to change this value ? [y/N] : $RESET_CLR"
        read USER_RESPONSE

        if [ "$USER_RESPONSE" == "y" ]; then
            echo -ne "${YELLOW}Please enter the new battery charge threshold [60 or 80 or 100](%) : $RESET_CLR"
            read BAT_CHARGE_THRESHOLD

            while [[ ! $BAT_CHARGE_THRESHOLD =~ ^(60|80|100)$ ]]; do
                echo -ne "[$RED Invalid value $RESET_CLR] ${YELLOW}Please enter one of these values [60 or 80 or 100](%) : $RESET_CLR"
                read BAT_CHARGE_THRESHOLD
            done

            if [ "$IS_SERVICE_EXIST" == "false" ]; then
                echo -n "Creating the service file : "
            else
                echo -n "Updating the service file : "
            fi

            echo "[Unit]
            \t\t\tDescription=Set the bat charge threshold
            \t\t\tAfter=multi-user.target
            \t\t\tStartLimitIntervalSec=30
            \t\t\tStartLimitBurst=2

            \t\t\t[Service]
            \t\t\tType=oneshot
            \t\t\tRestart=on-failure
            \t\t\tExecStart=/bin/bash -c 'echo $BAT_CHARGE_THRESHOLD >/sys/class/power_supply/$BAT_DIR_NAME/charge_control_end_threshold'

            \t\t\t[Install]
            \t\t\tWantedBy=multi-user.target
            \t\t\t" >$BAT_SERVICE_FILE_PATH
            check_cmd

            if [ "$IS_SERVICE_EXIST" == "false" ]; then
                echo -n "Activating and starting up the service : "
                sudo systemctl enable --now bat-charge-threshold.service >/dev/null
                check_cmd
            else
                echo -n "Reloading systemctl daemon : "
                sudo systemctl daemon-reload >/dev/null
                check_cmd

                echo -n "Restarting the service : "
                sudo systemctl restart bat-charge-threshold.service >/dev/null
                check_cmd
            fi

            echo -n "Check that the service is activated and operating correctly : "
            systemctl status bat-charge-threshold | grep -qE "enabled|SUCCESS" >/dev/null
            check_cmd

            echo -ne "Checking the new battery charge threshold value :$CYAN $(cat /sys/class/power_supply/$BAT_DIR_NAME/charge_control_end_threshold)% $RESET_CLR"
            if [ "$(cat /sys/class/power_supply/$BAT_DIR_NAME/charge_control_end_threshold)" == "$BAT_CHARGE_THRESHOLD" ]; then
                check_cmd
            else
                check_cmd
            fi

            echo -e "Current battery status :$CYAN $(cat /sys/class/power_supply/$BAT_DIR_NAME/status)"
            
            echo -e "${GREEN}Script completed"

            break
        else
            echo "Battery charge threshold not modified."
            exit 0
        fi
    fi
done

if [ "$IS_COMPATIBLE_DEVICE" == "false" ]; then
    echo -e "${RED}This device does not have the ability to configure the battery charge threshold"
fi
### SCRIPT END ###