#!/bin/bash

#####################################################################
# Print warning message.

function warningv()
{
    echo "$*" >&2
}

#####################################################################
# Print error message and exit.

function error()
{
    echo "$*" >&2
    exit 1
}

function install_docker()
{
  sudo apt-get update
  sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

  sudo apt-get update
  sudo apt-get install docker-ce docker-ce-cli containerd.io -y
}

function install_compose()
{
  sudo curl -L "https://github.com/docker/compose/releases/download/1.28.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

  sudo chmod +x /usr/local/bin/docker-compose

  # docker-compose --version
}


#####################################################################
# Ask yesno question.
#
# Usage; yesno OPTIONS QUESTION
#
#   Options;
#     --timeout N    Timeout if no input seen in N seconds.
#     --default ANS  Use ANS as the default answer on timeout or
#                    if an empty answer is provided.
#
# Exit status is the answer.

function yesno()
{
    local ans
    local ok=0
    local timeout=0
    local default
    local t

    while [[ "$1" ]]
    do
        case "$1" in
        --default)
            shift
            default=$1
            if [[ ! "$default" ]]; then error "Missing default value"; fi
            t=$(tr '[;upper;]' '[;lower;]' <<<$default)

            if [[ "$t" != 'y'  &&  "$t" != 'yes'  &&  "$t" != 'n'  &&  "$t" != 'no' ]]; then
                error "Illegal default answer; $default"
            fi
            default=$t
            shift
            ;;

        --timeout)
            shift
            timeout=$1
            if [[ ! "$timeout" ]]; then error "Missing timeout value"; fi
            if [[ ! "$timeout" =~ ^[0-9][0-9]*$ ]]; then error "Illegal timeout value; $timeout"; fi
            shift
            ;;

        -*)
            error "Unrecognized option; $1"
            ;;

        *)
            break
            ;;
        esac
    done

    if [[ $timeout -ne 0  &&  ! "$default" ]]; then
        error "Non-zero timeout requires a default answer"
    fi

    if [[ ! "$*" ]]; then error "Missing question"; fi

    while [[ $ok -eq 0 ]]
    do
        if [[ $timeout -ne 0 ]]; then
            if ! read -t $timeout -p "$*" ans; then
                ans=$default
            else
                # Turn off timeout if answer entered.
                timeout=0
                if [[ ! "$ans" ]]; then ans=$default; fi
            fi
        else
            read -p "$*" ans
            if [[ ! "$ans" ]]; then
                ans=$default
            else
                ans=$(tr '[;upper;]' '[;lower;]' <<<$ans)
            fi 
        fi

        if [[ "$ans" == 'y'  ||  "$ans" == 'yes'  ||  "$ans" == 'n'  ||  "$ans" == 'no' ]]; then
            ok=1
        fi

        if [[ $ok -eq 0 ]]; then warning "Valid answers are; yes y no n"; fi
    done
    [[ "$ans" = "y" || "$ans" == "yes" ]]
}

declare -a PROFILES

echo -e "\n\n"\
"+*********************************************************\n"\
"**                                                      **\n"\
"**             CIPio Installer v1.0 Beta                **\n"\
"**                                                      **\n"\
"** Welcome to the Common Integrtion Platform Installer  **\n"\
"**                                                      **\n"\
"** Default containers include the following:            **\n"\
"**  - Node-Red                                          **\n"\
"**  - InfluxDB                                          **\n"\
"**  - MongoDB and Mongo Express                         **\n"\
"**  - Grafana                                           **\n"\
"**  - Portainer                                         **\n"\
"**  - Watchtower                                        **\n"\
"**                                                      **\n"\
"**  Hit Ctrl-C anytime to abort setup                   **\n"\
"**********************************************************\n\n"


if [[ "$EUID" != 0 ]]; then
  echo "We need to elevate you to root level. Please enter root password"
  sudo -k
  if sudo true; then
    echo "Good, you are now at root level"
  else
    error "Incorrect password.. Exiting installation process"
  fi
fi

echo -e "\n"
echo "Checking for Docker..."
if hash docker 2>/dev/null; then
  echo "It appears you already have docker installed. Good."
else
  echo "We need to first install docker on your system. Hit <ENTER> to continue:"
  read

  install_docker 
  
  if hash docker 2>/dev/null; then
    echo "Docker now installed."
    sudo addgroup docker
    sudo usermod -aG docker ${USER}
  else
    error "Installation od Docker has failed. Exiting setup"
  fi
fi

echo -e "\n"
echo "Checking for Docker-Compose..."
if hash docker-compose 2>/dev/null; then
  echo "It appears you already have docker-compose installed. Good."
else
  echo "We need to install docker-compose on your system. Hit <ENTER> to continue:"
  read

  install_compose

  if hash docker-compose 2>/dev/null; then
    echo "Docker-Compose now installed."
  else
    error "Installation of Docker-Compose has failed. Exiting setup"
  fi
fi


echo -e "\n"

echo -e "Please provide the path to the folder which will become the root folder of our docker local volumes.\n"\
"The default path is /svr/docker. Do not use a trailing slash"
read -p "Path to local volume root folder: " -e -i "/srv/docker" CIPIOROOT 

echo "CIPIOROOT=$CIPIOROOT" > .env
echo "COMPOSE_PROJECT_NAME=cipio" >> .env

echo -e "\n"
## Install all the default containers?
if yesno --default yes "Would you like to install all the default containers for CIPio (Y/n) ? "; then
  echo "All default containers will be installed."
  PROFILES+=("default")
  ## echo "MONGOUSER=root">> .env
  ## echo "MONGOPW=root">> .env
else
  echo -e "\n"
  ## Node Red single instance
  if yesno --default yes "Would you like to install Node-Red? (Y/n)  ? "; then
    echo "Node-Red will be installed."
    PROFILES+=("nodered")
  else
    echo "Skipping Node-Red"
  fi

  echo -e "\n"
  ## MongoDB and Mongo Express
  if yesno --default yes "Would you like to install MongoDB? (Y/n)  ? "; then
    echo "MongoDB will be installed."
    PROFILES+=("mongodb")
    
    ## echo "MONGOUSER=root">> .env
    ## echo "MONGOPW=root">> .env

    if yesno --default yes "Would you like to install Mongo Express? (Y/n)  ? "; then
      echo "Mongo Express will be installed"
      PROFILES+=("mongoexpress")
    else
      echo "Skipping Mongo Express"
    fi
  else
    echo "Skipping MongoDB and Mongo Express..."
  fi

  echo -e "\n"
  ## Mosquitto
  if yesno --default yes "Would you like to install Mosquitto MQTT broker? (Y/n)  ? "; then
    echo "Mosquitto/MQTT will be installed."
    PROFILES+=("mosquitto")
  else
    echo "Skipping Mosquitto/MQTT..."
  fi

  echo -e "\n"
  ## InfluxDB
  if yesno --default yes "Would you like to install InfluxDB 1.8? (Y/n)  ? "; then
    echo "InfluxDB 1.8 will be installed."
    PROFILES+=("influxdb")
  else
    if yesno --default yes "Would you like to install InfluxDB 2.x? (Y/n)  ? "; then
      echo "InfluxDB 2.x will be installed. Use port 8087 to connect."
      PROFILES+=("influxdb2")
    else
      echo "Skipping InfluxDB"
    fi
  fi

  echo -e "\n"
  ## Grafana
  if yesno --default yes "Would you like to install Grafana? (Y/n)  ? "; then
    echo "Grafana will be installed."
    PROFILES+=("grafana")
  else
    echo "Skipping Grafana..."
  fi

  echo -e "\n"
  ## Portainer
  if yesno --default yes "Would you like to install Protainer? (Y/n)  ? "; then
    echo "Portainer will be installed."
    PROFILES+=("portainer")
  else
    echo "Skipping Portainer..."
  fi

  echo -e "\n"
  ## Watchtower
  if yesno --default yes "Would you like to install Watchtower? (Y/n)  ? "; then
    echo "Watchtowner will be installed."
    PROFILES+=("watchtower")
  else
    echo "Skipping Watchtower..."
  fi
fi

echo -e "\n\n"

read -p "Hit return to start the installation of the following caontainers:( ${PROFILES[*]} )"

## Get the path to the currently running script
## We need this for when we su to the current user 
## We need to sudo su <user> to that we pick up the new group assignment
##########################################################################

SCRIPT_PATH="`dirname \"$0\"`"              # relative
SCRIPT_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

## Put the profiles in the .env file.
## We need to do this to persist the profiles. The original
## way of using an env var is lost when sudo su <user>
## Old way>> COMPOSE_PROFILE=$(IFS=,; echo "${PROFILES[*]}") docker-compose up -d
#############################################################
echo COMPOSE_PROFILE=$(IFS=,; echo "${PROFILES[*]}") >> .env
sudo su -c "cd ${SCRIPT_PATH} && docker-compose up -d" - ${USER}

## We need to set the proper owner to the nodered volume
##
if [[ ${PROFILES[*]} =~ (^|[[:space:]])'nodered'($|[[:space:]]) ]] || [[ ${PROFILES[*]} =~ (^|[[:space:]])'default'($|[[:space:]]) ]]; then
  echo "Updating ownership of ${CIPIOROOT}/node-red..."
  sudo docker stop node-red
  sudo chown -R ${USER}:${USER} ${CIPIOROOT}/node-red
  echo "Restarting node-red container..."
  sudo docker restart node-red
fi

if [[ ${PROFILES[*]} =~ (^|[[:space:]])'mosquitto'($|[[:space:]]) ]] || [[ ${PROFILES[*]} =~ (^|[[:space:]])'default'($|[[:space:]]) ]];then
  # echo "Updating ownership of ${CIPIOROOT}/mosquitto..."
  # sudo mkdir ${CIPIOROOT}/mosquitto
  # sudo mkdir ${CIPIOROOT}/mosquitto/data
  # sudo mkdir ${CIPIOROOT}/mosquitto/log
  # sudo mkdir ${CIPIOROOT}/mosquitto/config
  echo "Copying config files to ${CIPIOROOT}/mosquitto/config..."
  sudo cp -v ./mqtt/mosquitto.conf ${CIPIOROOT}/mosquitto/config
  sudo cp -v ./mqtt/passwd ${CIPIOROOT}/mosquitto/config
  echo "Restarting Mosquitto/MQTT container..."
  sudo docker restart mosquitto
fi


echo -e "\n\n[Note: You may need to restart your terminal in order to do certain docker commands without using sudo]\n\n"

echo "Installation of CIPio complete"

exit 0

