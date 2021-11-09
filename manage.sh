#!/bin/bash

cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" || exit

if [[ ! -f "./.env" ]]
then
    printf "Please create the .env file based on .env.dist"
    exit
fi

if [[ $(uname -s) =~ \MINGW* ]];
then
    export MSYS_NO_PATHCONV=1
    export COMPOSE_CONVERT_WINDOWS_PATHS=1
fi

LOG_PATH="./docker_logs.txt"

source ./.env

if [[ -z ${COMPOSE_PROJECT_NAME+x} ]]; then printf "\e[31mThe 'COMPOSE_PROJECT_NAME' variable is not defined.\e[0m\n"; exit 1; fi

# Clear logs
echo "" > ${LOG_PATH}

Success() {
    printf "\e[32m%s\e[0m\n" "$1"
}

Error() {
    printf "\e[31m%s\e[0m\n" "$1"
}

Warning() {
    printf "\e[31;43m%s\e[0m\n" "$1"
}

Help() {
    printf "\e[2m%s\e[0m\n" "$1"
}

DoneOrError() {
    if [[ $1 -eq 0 ]]
    then
        Success 'done'
    else
        Error 'error'
        exit 1
    fi
}

Confirm () {
    printf "\n"
    choice=""
    while [[ "$choice" != "n" ]] && [[ "$choice" != "y" ]]
    do
        printf "Do you want to continue ? (N/Y)"
        read -r choice
        choice=$(echo "${choice}" | tr '[:upper:]' '[:lower:]')
    done
    if [[ "$choice" = "n" ]]; then
        printf "\nAbort by user.\n"
        exit 0
    fi
    printf "\n"
}

IsUpAndRunning() {
    if docker ps --format '{{.Names}}' | grep -q "$1\$"
    then
        return 0
    fi
    return 1
}

CheckProxyUpAndRunning() {
    if ! IsUpAndRunning proxy_nginx
    then
        Error "Proxy is not up and running."
        exit 1
    fi
}

NetworkExists() {
    if docker network ls --format '{{.Name}}' | grep -q "$1\$"
    then
        return 0
    fi
    return 1
}

ComposeUp() {
    if IsUpAndRunning proxy_nginx
    then
        Error "Already up and running."
        exit 1
    fi

    printf "Composing \e[1;33mup\e[0m ... "
    docker-compose up -d >> ${LOG_PATH} 2>&1
    DoneOrError $?

    if [[ -f ./networks.list ]]
    then
        while IFS='' read -r NETWORK || [[ -n "$NETWORK" ]]; do
            if [[ "" != "${NETWORK}" ]]
            then
                Connect "${NETWORK}"
            fi
        done < ./networks.list

        sleep 1
        docker restart proxy_nginx
    fi
}

ComposeDown() {
    printf "Composing \e[1;33mdown\e[0m ... "
    docker-compose down -v --remove-orphans >> ${LOG_PATH} 2>&1
    DoneOrError $?
}

Execute() {
    CheckProxyUpAndRunning

    printf "Executing %s\n" "$1"

    printf "\n"
    # shellcheck disable=SC1001
    if [[ "$(uname -s)" = \MINGW* ]]
    then
        winpty docker exec -it proxy_nginx $1
    else
        docker exec -it proxy_nginx $1
    fi
    printf "\n"
}

GenCert() {
    if [[ "" == "$1" ]]
    then
        Error "Please provide a virtual host name."
        exit 1
    fi

    Execute "./gencert.sh $1"
}

Connect() {
    CheckProxyUpAndRunning

    NETWORK="$(echo -e "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    if ! NetworkExists "${NETWORK}"
    then
        Error "Network '${NETWORK}' does not exist."
        exit
    fi

    printf "Connecting to \e[1;33m%s\e[0m network ... " "${NETWORK}"

    docker network connect "${NETWORK}" proxy_nginx >> ${LOG_PATH} 2>&1
    if [[ $? -ne 0 ]]
    then
        Error 'error'
        exit 1
    fi

    docker network connect ${NETWORK} proxy_generator >> ${LOG_PATH} 2>&1
    if [[ $? -ne 0 ]]
    then
        Error 'error'
        exit 1
    fi

    printf "\e[32mdone\e[0m\n"

    if [[ -f ./networks.list ]];
    then
        if [[ "$(cat ./networks.list | grep ${NETWORK})" ]]; then return 0; fi
    fi

    echo $1 >> ./networks.list
}

Reset() {
    ComposeDown
    printf "Clearing configured networks and certificates ... "

    if [[ -f ./networks.list ]]
    then
        rm ./networks.list
    fi

    if [[ -d ./volumes/certs/ ]]
    then
        rm -f ./volumes/certs/*
    fi

    printf "\e[32mdone\e[0m\n"
    ComposeUp
}

# ----------------------------- EXEC -----------------------------

case $1 in
    up)
        ComposeUp
    ;;
    down)
        ComposeDown
    ;;
    gencert)
        GenCert "$2"
    ;;
    connect)
        Connect "$2"
    ;;
    restart)
        if ! IsUpAndRunning proxy_nginx
        then
            printf "\e[31mNot up and running.\e[0m\n"
            exit 1
        fi

        docker restart proxy_nginx
    ;;
    dump)
        docker exec -t proxy_nginx cat /etc/nginx/conf.d/default.conf
    ;;
    test)
        docker exec proxy_nginx nginx -t
    ;;
    reset)
        Warning "Configured networks and certificates will be lost."

        Confirm

        Reset
    ;;
    *)
        printf "\e[2mUsage:  ./manage.sh [action] [options]

  \e[0mup\e[2m             Create and start containers for the [env] environment.
  \e[0mdown\e[2m           Stop and remove containers for the [env] environment.
  \e[0mgencert\e[2m name   Generates certificates for [name] domain.
  \e[0mconnect\e[2m name   Connects proxy to [name] network.
  \e[0mrestart\e[2m        Restart nginx container.
  \e[0mdump\e[2m           Dump nginx config.
  \e[0mtest\e[2m           Test nginx config.
  \e[0mreset\e[2m          Reset the containers and network connections.
\e[0m"
    ;;
esac

printf "\n"
