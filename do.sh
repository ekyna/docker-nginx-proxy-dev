#!/bin/bash

if [[ ! -f "./.env" ]]
then
    printf "Please create the .env file based on .env.dist"
    exit
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_PATH="$DIR/docker_logs.txt"

source ./.env

IsUpAndRunning() {
    if [[ "$(docker ps | grep $1)" ]]
    then
        return 1
    fi
    return 0
}

ComposeUp() {
    IsUpAndRunning "${COMPOSE_PROJECT_NAME}_nginx"
    if [[ $? -eq 1 ]]
    then
        printf "\e[31mAlready up and running.\e[0m\n"
        exit 1
    fi

    printf "Composing \e[1;33mup\e[0m ... "
    cd ${DIR} && \
        docker-compose up -d >> ${LOG_PATH} 2>&1 \
            && printf "\e[32mdone\e[0m\n" \
            || (printf "\e[31merror\e[0m\n" && exit 1)
}

ComposeDown() {
    printf "Composing \e[1;33mdown\e[0m ... "
    cd ${DIR} && \
        docker-compose down -v --remove-orphans >> ${LOG_PATH} 2>&1 \
            && printf "\e[32mdone\e[0m\n" \
            || (printf "\e[31merror\e[0m\n" && exit 1)
}

Execute() {
    IsUpAndRunning "${COMPOSE_PROJECT_NAME}_nginx"
    if [[ $? -eq 0 ]]
    then
        printf "\e[31mNot up and running.\e[0m\n"
        exit 1
    fi

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
    if [[ "$(docker network ls | grep $1)" == "" ]]
    then
        printf "\e[31mNetwork '$1' does not exist.\e[0m\n"
        exit
    fi

    docker network connect $1 ${COMPOSE_PROJECT_NAME}_nginx
    docker network connect $1 ${COMPOSE_PROJECT_NAME}_nginx_gen
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
