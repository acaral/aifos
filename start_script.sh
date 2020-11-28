#/bin/bash

sudo apt-get update
sudo apt-get install nginx python3 python3-pip -y
sudo pip3 install certbot-nginx
cat > ngrok.smartapphouses.com << EOF
server {
        server_name ngrok.smartapphouses.com;
        location / { proxy_pass http://localhost:3333/;}
}
EOF

sudo cp ngrok.smartapphouses.com /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/ngrok.smartapphouses.com /etc/nginx/sites-enabled/
sudo certbot --nginx -d ngrok.smartapphouses.com --non-interactive --agree-tos -m alejandro.caral.ferro@gmail.com
