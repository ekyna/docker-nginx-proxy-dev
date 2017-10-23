#!/bin/bash

if [[ ! -f "./.env" ]]
then
    printf "Please create the .env file based on .env.dist"
    exit
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_PATH="$DIR/docker_logs.txt"

source ./.env

if [[ "" == "${COMPOSE_PROJECT_NAME}" ]]; then printf "\e[31mCOMPOSE_PROJECT_NAME env variable is not set.\e[0m\n"; exit; fi

# Clear logs
echo "" > ${LOG_PATH}

IsUpAndRunning() {
    if [[ "$(docker ps | grep ${COMPOSE_PROJECT_NAME}_$1)" ]]
    then
        return 0
    fi
    return 1
}

CheckProxyUpAndRunning() {
    if ! IsUpAndRunning nginx
    then
        printf "\e[31mProxy is not up and running.\e[0m\n"
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
        printf "\e[31mAlready up and running.\e[0m\n"
        exit 1
    fi

    printf "Composing \e[1;33mup\e[0m ... "
    cd ${DIR} && \
        docker-compose up -d >> ${LOG_PATH} 2>&1 \
            && printf "\e[32mdone\e[0m\n" \
            || (printf "\e[31merror\e[0m\n" && exit 1)

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
    cd ${DIR} && \
        docker-compose down -v --remove-orphans >> ${LOG_PATH} 2>&1 \
            && printf "\e[32mdone\e[0m\n" \
            || (printf "\e[31merror\e[0m\n" && exit 1)
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
        printf "\e[31mPlease provide a virtual host name.\e[0m\n"
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

    docker network connect ${NETWORK} ${COMPOSE_PROJECT_NAME}_nginx >> ${LOG_PATH} 2>&1 || (printf "\e[31merror\e[0m\n" && exit 1)
    docker network connect ${NETWORK} ${COMPOSE_PROJECT_NAME}_generator >> ${LOG_PATH} 2>&1 || (printf "\e[31merror\e[0m\n" && exit 1)

    printf "\e[32mdone\e[0m\n"

    if [[ -f ./networks.list ]];
    then
        if [[ "$(cat ./networks.list | grep ${NETWORK})" ]]; then return 0; fi
    fi

    echo $1 >> ./networks.list
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
    dump)
        Execute "cat //etc/nginx/conf.d/default.conf"
    ;;
    *)
        Help "Usage:  ./do.sh [action] [options]

\t\e[0mup\e[2m\t\t\t Create and start containers for the [env] environment.
\t\e[0mdown\e[2m\t\t Stop and remove containers for the [env] environment.
\t\e[0mgencert\e[2m name\t\t Generates certificates for [name] domain.
\t\e[0mconnect\e[2m name\t\t Connects proxy to [name] network.
\t\e[0mdump\e[2m name\t\t Dump nginx config.
"
    ;;
esac

printf "\n"
