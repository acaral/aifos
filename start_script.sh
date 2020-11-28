#!/bin/bash

sudo apt-get update
sudo apt-get install nginx python3 python3-pip -y
sudo pip3 install certbot-nginx
cat > ${project}.smartapphouses.com << EOF
server {
        server_name ${project}.smartapphouses.com;
        location / { proxy_pass http://localhost:${port}/;}
}
EOF

sudo cp ${var.project}.smartapphouses.com /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/${project}.smartapphouses.com /etc/nginx/sites-enabled/
sudo certbot --nginx -d ${project}.smartapphouses.com --non-interactive --agree-tos -m alejandro.caral.ferro@gmail.com
