#!/usr/bin/env bash
sudo apt update -y
sudo apt install nginx -y 
sudo systemctl enable nginx
sudo systemctl start nginx

sudo chmod -R 777 /usr/share/nginx/html/index.html

myhostname=`curl http://169.254.169.254/latest/meta-data/hostname`

sudo rm -f /var/www/html/
sudo cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<html>
   <body bgcolor="black">
     <h2 align="center"><font color="white">Web Server from Terraform for my EPAM task</h2><br><p align="center">
     <font color="gold">This server has ZeroDownTime and <font color="green">Green/<font color="blue">Blue <font color="gold">deployment<br><br>
     <font color="white">Selected Private Server IP: <font color="white">$myhostname<br><br>
     <h4 align="center"><font color="green">Created by Kozlov Valentin v.2</h4>
   </body>
</html>
EOF

sudo systemctl reload nginx