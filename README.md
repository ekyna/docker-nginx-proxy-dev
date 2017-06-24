ekyna/docker-nginx-proxy-dev
===

Docker Nginx proxy with self signed certificates for local development.

#### Usage

1. Clone and run the proxy: 

        git clone https://github.com/ekyna/docker-nginx-proxy.git 
        cd ./docker-nginx-proxy
        ./do.sh up        

2. Configure your website: 
    
    _example with docker composer v2_

        version: '2'
        networks:
          default:
            external:
              name: example-network
        services:
          example:
            image: nginx
            environment:
              - VIRTUAL_HOST=example.dev
              - VIRTUAL_NETWORK=example-network
              - VIRTUAL_PORT=80

3. Create your network and connect it to the proxy services:

        docker network create example-network
        ./do.sh connect example-network

4. Generate certs for your virtual host:
        
        ./do.sh gencert example.dev

3. Run your website:

       cd ./example-website
       docker-compose up -d 
