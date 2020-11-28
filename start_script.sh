#/bin/bash

sudo apt-get update
sudo apt-get install nginx python3 python3-pip -y
sudo pip3 install certbot-nginx
cat > aifos.smartapphouses.com << EOF
server {
        server_name aifos.smartapphouses.com;
        location / { proxy_pass http://localhost:3333/;}
}
EOF

sudo cp aifos.smartapphouses.com /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/aifos.ngrok.smartapphouses.com /etc/nginx/sites-enabled/
sudo certbot --nginx -d aifos.smartapphouses.com --non-interactive --agree-tos -m alejandro.caral.ferro@gmail.com
