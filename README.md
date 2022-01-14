ekyna/docker-nginx-proxy-dev
===

Docker Nginx proxy with self-signed certificates for local development.

#### Usage

1. Clone and run the proxy: 

        git clone https://github.com/ekyna/docker-nginx-proxy.git 
        cd ./docker-nginx-proxy
        ./manage.sh up        

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
              - VIRTUAL_PORT=80

3. Create your network and connect it to the proxy services:

        docker network create example-network
        ./manage.sh connect example-network

4. Generate certs for your virtual host:
        
        ./manage.sh gencert example.dev

5. Trust the CA

   Follow [this guide](https://betterprogramming.pub/how-to-create-trusted-ssl-certificates-for-your-local-development-13fd5aad29c6#ee40)

6. Run your website:

       cd ./example-website
       docker-compose up -d 
