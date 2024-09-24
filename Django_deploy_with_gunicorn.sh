#!/bin/bash

echo "Choose directory to setup app and virtualenv:"
echo "======================================================================="
echo "EXAMPLE: /path/to/directory"
echo "======================================================================="
read main_dir
main_path="${main_dir%/}"

echo "======================================================================="
echo "project directory name:"
echo "======================================================================="

read name
virenv=${name}_env

echo "======================================================================="
echo "Directory and project Folder: $main_path/$name "
echo "======================================================================="
echo "virtualenv name:"
echo "======================================================================="
echo ">>> $virenv <<<"
echo "Directory of virtualenv: $main_path/VENV/$virenv "
echo "======================================================================="
echo "python version:"
echo "======================================================================="
read ver
###################################################################################
#project folder creation:
###################################################################################
if [ -d "$main_path/$name" ]; then
    echo "Folder already exists working on next step."
else
    # Create the folder
    sudo mkdir "$main_path/$name"
    echo "Folder created successfully."
fi
#project folder:

sudo chown -R $USER:$USER $main_path/$name
sudo chmod -R 775 $main_path/$name
project_dir=$main_path/$name

###################################################################################
# VENV folder check:
###################################################################################
if [ -d "$main_path/VENV" ]; then
    echo "Folder already exists don't worry"
else
    # Create the folder
    sudo mkdir "$main_path/VENV"
    echo "Folder created successfully."
fi

sudo chown -R $USER:$USER $main_path/VENV
sudo chmod -R 775 $main_path/VENV

###################################################################################
#env creation:
###################################################################################

sudo apt-get install python"$ver"-dev python"$ver"-venv

if [ -d "$main_path/VENV/$virenv" ]; then
    echo "Folder already exists."
else
    # Create the folder
    cd $main_path/VENV
    python"$ver" -m venv "$virenv"
    if source $main_path/VENV/$virenv/bin/activate; then
        echo "Env created"
    else
       # Create the folder
        sudo rm -rf $main_path/"$name"
        sudo rm -rf $main_path/VENV/$virenv
    fi

fi

venv_path=$main_path/VENV/$virenv

##################################################################################
#general service folder creation:
##################################################################################

if [ -d "$main_path/services" ]; then
    echo "Folder already exists don't worry"
else
    # Create the folder
    sudo mkdir $main_path/services
    echo "Folder created successfully."
fi

sudo chown -R $USER:$USER $main_path/services
sudo chmod -R 775 $main_path/services

#################################################################################
#Gunicorn file creation:
#################################################################################

socket_file=$project_dir/gunicorn.sock
touch $main_path/services/gunicorn_$name.service
cat > $main_path/services/gunicorn_$name.service << EOL
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=$USER
Group=www-data
WorkingDirectory=$project_dir
ExecStart=$venv_path/bin/gunicorn --workers 3 --limit-request-line 8000 --bind unix:$socket_file conf.wsgi:application

[Install]
WantedBy=multi-user.target
EOL

# copy file to systemd

sudo cp $main_path/services/gunicorn_$name.service /etc/systemd/system/
sudo chmod 775 /etc/systemd/system/gunicorn_$name.service

################################################################################
#install nginx and configure nginx sites-available
################################################################################

sudo apt install nginx
echo "enter server name:"
read server
echo "enter port number for nginx:"
read port
touch $main_path/services/${name}_nginx
cat > $main_path/services/${name}_nginx << EOL
server {
listen $port;
server_name $server;
location = /favicon.ico { access_log off; log_not_found off; }
location /static/ {
root $project_dir;
}
location /media/ {
alias $project_dir/media/;
}
location / {
include proxy_params;
proxy_pass http://unix:$socket_file;
}
}
EOL

sudo cp $main_path/services/${name}_nginx /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/${name}_nginx /etc/nginx/sites-enabled/

#############################################################################
# celery conf:
#############################################################################

if [ -d "$main_path/celery_service/conf" ]; then
    echo "Folder already exists."
else
    # Create the folder
    sudo mkdir -p "$main_path/celery_service/conf"
    sudo mkdir "$main_path/celery_service/pids"
    sudo chown -R $USER:$USER $main_path/celery_service
    echo "Folder created successfully."
fi
sudo chown -R $USER:$USER $main_path/celery_service
sudo chmod -R 775 $main_path/celery_service

touch $main_path/celery_service/conf/${name}_celery
cat > $main_path/celery_service/conf/${name}_celery << EOL
me of nodes to start
# here we have a single node
CELERYD_NODES="$name"

# Absolute or relative path to the 'celery' command:
CELERY_BIN="$venv_path/bin/celery"

# App instance to use
CELERY_APP="conf"

# How to call manage.py
CELERYD_MULTI="multi"

# Extra command-line arguments to the worker
CELERYD_OPTS="--time-limit=300 --concurrency=1"

# - %n will be replaced with the first part of the nodename.
# - %I will be replaced with the current child process index
#   and is important when using the prefork pool to avoid race conditions.
CELERYD_PID_FILE="$main_path/celery_service/pids/%n.pid"
CELERYD_LOG_FILE="$main_path/celery_service/%n%I.log"
CELERYD_LOG_LEVEL="DEBUG"
EOL

#celery systemd conf:

CELERY_BIN='${CELERY_BIN}'
CELERYD_NODES='${CELERYD_NODES}'
CELERY_APP='${CELERY_APP}'
CELERYD_PID_FILE='${CELERYD_PID_FILE}'
CELERYD_LOG_FILE='${CELERYD_LOG_FILE}'
CELERYD_LOG_LEVEL='${CELERYD_LOG_LEVEL}'
CELERYD_OPTS='${CELERYD_OPTS}'


echo "
[Unit]
Description=Celery Service
After=network.target

[Service]
Type=forking
User=$USER
Group=$USER
EnvironmentFile=-$main_path/celery_service/conf/${name}_celery
WorkingDirectory=$project_dir
ExecStart=/bin/sh -c '${CELERY_BIN} multi start ${CELERYD_NODES} \
  -A ${CELERY_APP} --pidfile=${CELERYD_PID_FILE} \
  --logfile=${CELERYD_LOG_FILE} --loglevel=${CELERYD_LOG_LEVEL} ${CELERYD_OPTS}'
ExecStop=/bin/sh -c '${CELERY_BIN} multi stopwait ${CELERYD_NODES} \
  --pidfile=${CELERYD_PID_FILE}'
ExecReload=/bin/sh -c '${CELERY_BIN} multi restart ${CELERYD_NODES} \
  -A ${CELERY_APP} --pidfile=${CELERYD_PID_FILE} \
  --logfile=${CELERYD_LOG_FILE} --loglevel=${CELERYD_LOG_LEVEL} ${CELERYD_OPTS}'

[Install]
WantedBy=multi-user.target" >> $main_path/services/celery_$name.service

#copy in systemd:
sudo cp $main_path/services/celery_$name.service /etc/systemd/system/
sudo chmod 775 /etc/systemd/system/celery_$name.service

