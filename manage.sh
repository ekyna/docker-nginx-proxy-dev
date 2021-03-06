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
    printf "\e[32m$1\e[0m\n"
}

Error() {
    printf "\e[31m$1\e[0m\n"
}

Warning() {
    printf "\n\e[31;43m$1\e[0m\n"
}

Help() {
    printf "\n\e[2m$1\e[0m\n";
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
        read choice
        choice=$(echo ${choice} | tr '[:upper:]' '[:lower:]')
    done
    if [[ "$choice" = "n" ]]; then
        printf "\nAbort by user.\n"
        exit 0
    fi
    printf "\n"
}

IsUpAndRunning() {
    if [[ "$(docker ps --format '{{.Names}}' | grep ${COMPOSE_PROJECT_NAME}_$1\$)" ]]
    then
        return 0
    fi
    return 1
}

CheckProxyUpAndRunning() {
    if ! IsUpAndRunning nginx
    then
        Error "Proxy is not up and running."
        exit 1
    fi
}

NetworkExists() {
    if [[ "$(docker network ls | grep $1)" ]]
    then
        return 0
    fi
    return 1
}

ComposeUp() {
    if IsUpAndRunning nginx
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
                Connect ${NETWORK}
            fi
        done < ./networks.list

        sleep 1
        docker restart ${COMPOSE_PROJECT_NAME}_nginx
    fi
}

ComposeDown() {
    printf "Composing \e[1;33mdown\e[0m ... "
    docker-compose down -v --remove-orphans >> ${LOG_PATH} 2>&1
    DoneOrError $?
}

Execute() {
    CheckProxyUpAndRunning

    printf "Executing $1\n"

    printf "\n"
    if [[ "$(uname -s)" = \MINGW* ]]
    then
        winpty docker exec -it ${COMPOSE_PROJECT_NAME}_nginx $1
    else
        docker exec -it ${COMPOSE_PROJECT_NAME}_nginx $1
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

    if ! NetworkExists ${NETWORK}
    then
        printf "\e[31mNetwork '${NETWORK}' does not exist.\e[0m\n"
        exit
    fi

    printf "Connecting to \e[1;33m${NETWORK}\e[0m network ... "

    docker network connect ${NETWORK} ${COMPOSE_PROJECT_NAME}_nginx >> ${LOG_PATH} 2>&1
    if [[ $? -ne 0 ]]
    then
        Error 'error'
        exit 1
    fi

    docker network connect ${NETWORK} ${COMPOSE_PROJECT_NAME}_generator >> ${LOG_PATH} 2>&1
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
        GenCert $2
    ;;
    connect)
        Connect $2
    ;;
    restart)
        if ! IsUpAndRunning nginx
        then
            printf "\e[31mNot up and running.\e[0m\n"
            exit 1
        fi

        docker restart ${COMPOSE_PROJECT_NAME}_nginx
    ;;
    dump)
        cat ./volumes/conf.d/default.conf
    ;;
    test)
        docker exec ${COMPOSE_PROJECT_NAME}_nginx nginx -t
    ;;
    reset)
        Warning "Configured networks and certificates will be lost."

        Confirm

        Reset
    ;;
    *)
        Help "Usage:  ./manage.sh [action] [options]

 - \e[0mup\e[2m\t\t Create and start containers for the [env] environment.
 - \e[0mdown\e[2m\t\t Stop and remove containers for the [env] environment.
 - \e[0mgencert\e[2m name\t Generates certificates for [name] domain.
 - \e[0mconnect\e[2m name\t Connects proxy to [name] network.
 - \e[restart\e[2m name\t Restart nginx container.
 - \e[0mdump\e[2m\t Dump nginx config.
 - \e[0mtest\e[2m\t Test nginx config.
 - \e[0mreset\e[2m\t Reset the containers and network connections.
"
    ;;
esac

printf "\n"
