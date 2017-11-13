#!/bin/bash

yum install -y httpd
service httpd start
groupadd www
usermod -a -G www centos
chown -R root:www /var/www
chmod 2775 /var/www
find /var/www -type d -exec sudo chmod 2775 {} +
find /var/www -type f -exec sudo chmod 0664 {} +
cd /var/www/html/
aws --region=us-east-2 s3 cp s3://ravi-assets/index.html .
service httpd restart

