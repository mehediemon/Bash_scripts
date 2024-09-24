# Set the database name and owner
echo "database name:"
read database_name
echo "database user name:"
read database_user
echo "database password:"
read database_pass

# Create the database
psql -h 127.0.0.1 -U postgres -c "CREATE DATABASE $database_name;"

# Connect to the newly created database
psql -h 127.0.0.1 -U postgres -d $database_name -c "

    -- Create the user
    CREATE USER $database_user WITH PASSWORD '$database_pass' superuser login;

    -- Grant all privileges to the user
    GRANT ALL PRIVILEGES ON DATABASE $database_name TO $database_user;

"
