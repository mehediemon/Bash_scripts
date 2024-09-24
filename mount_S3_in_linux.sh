#!/bin/bash
echo "awscli and s3fs is installing......."
sudo apt-get update -y
sudo apt-get install awscli -y
sudo apt-get install s3fs -y
echo "finished installing............"
echo "------------------------------------------------------"
read -p "enter the path to mount:" MAIN_PATH
read -p "enter the folder name to mount:" FOLDER_NAME
mkdir $MAIN_PATH/$FOLDER_NAME; cd $MAIN_PATH/$FOLDER_NAME;touch test1.txt

read -p "Enter Access Key ID:" AWS_ACCESS_KEY_ID
read -p "Enter Secret Key ID:" AWS_SECRET_KEY_ID
read -p "Enter Region:" AWS_REGION
read -p "Enter S3 Bucket Name:" BUCKET_NAME
echo "$AWS_ACCESS_KEY_ID:$AWS_SECRET_KEY_ID:$AWS_REGION" > $MAIN_PATH/s3fs-info;
cat $MAIN_PATH/s3fs-info
echo "$AWS_ACCESS_KEY_ID:$AWS_SECRET_KEY_ID" > $MAIN_PATH/.passwd-s3fs;
chmod 600 $MAIN_PATH/.passwd-s3fs
aws configure
aws s3 sync $MAIN_PATH/$FOLDER_NAME s3://$BUCKET_NAME
echo "
sudo s3fs $BUCKET_NAME $MAIN_PATH/$FOLDER_NAME  -o passwd_file=$MAIN_PATH/.passwd-s3fs,nonempty,rw,allow_other,mp_umask=002,uid=1000,gid=1000 -o url=http://s3.$AWS_REGION.amazonaws.com,endpoint=$AWS_REGION,use_path_request_style" >> $MAIN_PATH/s3rebootalt.sh
sudo s3fs $BUCKET_NAME $MAIN_PATH/$FOLDER_NAME  -o passwd_file=$MAIN_PATH/.passwd-s3fs,nonempty,rw,allow_other,mp_umask=002,uid=1000,gid=1000 -o url=http://s3.$AWS_REGION.amazonaws.com,endpoint=$AWS_REGION,use_path_request_style
mount|grep s3fs

#s3fs-test-101 /home/ubuntu/bucket fuse.s3fs _netdev,allow_other 0 0
