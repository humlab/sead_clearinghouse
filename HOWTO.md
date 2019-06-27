# HOWTO Enable reverse proxy on Debian with Apache
The QuerySEAD services can only be accessed through a reverse proxy that redirects external requests to the URL of the local application. The reverse proxy can easily be setup in Apache or Nginx, follow these steps for Apache setup.

1. Enable Apache modules proxy and proxy_http (proxy_load)
```bash
$ sudo a2enmod proxy
$ sudo a2enmod proxy_http
$ sudo a2enmod proxy_load
$ sudo a2enmod proxy_balancer # if load balancing
$ sudo a2enmod lbmethod_byrequests # if load balancing
```
2. Open port in /etc/apache2/ports.com (if not port 80)
3. Add and configure new virtual host
```
# /etc/apache2/sites-enabled/seadquery.humlab.umu.se.conf
<VirtualHost *:8089>
   ProxyPass "/" "http://www.example.com/"
   ProxyPassReverse "/"  "http://www.example.com/"
   # ...add logging configuration etc...
</VirtualHost>
```
4. Restart apache
```bash
$ sudo /etc/init.d/apache2 restart
```
5. Open “sitename:8080” to test connection

Note! A specific domain (querysead.humlab.umu.se) will be registered for QuerySEAD which will enable web access through SSL port 343.

# HOWTO Install and enable .NET Core on Debian

Instructions on how to install .NET Core on Debian can be found at microsoft.com
Install system components
```
$ sudo apt-get update
$ sudo apt-get install curl libunwind8 gettext apt-transport-https
```
Register product key
```
$ curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
$ sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
```
Add Microsoft feed list of to apt sources:
```
$ sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-debian-jessie-prod jessie main" > /etc/apt/sources.list.d/dotnetdev.list'
```
Install .NET Core SDK
```
$ sudo apt-get update
$ sudo apt-get install dotnet-sdk-2.0.0
```
Verify install
```
$ dotenet --version
```


# HOWTO Build and Publish QuerySEAD using CLI  (to be replaced by Docker and deprecated)
Note! The steps described below is fully implemented in bat script file “deploy_to_dev.bat” for the Windows 10 environment targeting the Debian linux release environment. The steps below is only needed when compiling on other environments.

To build and publish a new release of QuerySEAD using the dotnet CLI do the following:
Ascertain that the source code are updated to current release (and committed)
Open command prompt and move to project directory
```
> cd “path to your project”\query_sead_api_core
```
Optional: Ascertain that all unit tests are green.
```
> dotnet test
```
Optional: Clean output directory
```
> dotnet clean
```
Optional: Restore dependencies and project-specific tools
```
> dotnet restore
```
Optional: Build the project (publish will also build the project)
```
> dotnet build --configuration Release --runtime debian.8-x64
```
Use “dotnet publish” to compile the applications and produce all files necessary for deployment. Note that this is the only supported way to prepare an application for deployment. The application deployment can be framework-dependent (uses a shared run-time) or self-contained in which case the .NET Core runtime is published with the application.
```
> dotnet publish
```
...or...
```
> dotnet publish --configuration Release --runtime debian.8-x64 --self-contained
```
The ASP.NET Core application now reside in directory such as:
```
.\query_sead_api_core\query_sead_net\bin\Release\netcoreapp2.0\debian.8-x64\publish
```
Copy the entire folder to the target server using for instance WInSCP.

Prepare application on target server (move to proper location and change ownership and permission for the files.
```
$ sudo mkdir /var/webapps
$ sudo mv /some/path/publish /var/webapps/query_sead
```
...or...
```
$ sudo ln -s /some/path/publish /var/webapps/queary_sead
$ sudo chown -R www-data:www-data /var/webapps/query_sead/
$ sudo mkdir /var/www/.dotnet
$ sudo chown -R www-data:www-data /var/www/.dotnet/
```
Setup system to run as a service.
$ tbd

https://www.hanselman.com/blog/PublishingAnASPNETCoreWebsiteToACheapLinuxVMHost.aspx

# HOWTO Install Redis Key-Value Store (to be deprecated)

Redis is a popular open source key-value store, that operates in-memory but also persists the data on disk. Query SEAD uses Redis for caching and session data storage, as well as long term storage of facets configurations (saved links). Also see this tutorial.
Query SEAD uses the CacheManager as caching framework, and more specifically the .NET Core implementation CacheManager.Core. CacheManager has supports Redis as backend cache provider. CacheManager.Code can be installed with the nuget package manager.
Instructions on how to install Redis on Debian can be found at microsoft.com. Note that the Redis server should for security reasons, and as default configuration, only accepts local connections to “localhost:portnumber”.
Easy install (not the latest version)
```
$ sudo apt-get install redis-server -y
```
Or install latest stable version
```
sudo apt-get update
sudo apt-get install build-essential -y
wget http://download.redis.io/releases/redis-stable.tar.gz
tar xzf redis-stable.tar.gz
cd redis-stable && make
sudo apt-get install tcl8.5 -y
sudo make install
```
Install as server
```
$ cd utils && sudo ./install_server.sh
```
Manage the service
```
$ sudo service redis_6379 [start | stop | restart]
```

On Windows, use the NET Package manager to install the Redis nuget package. The install target folder are (typically):
%HOME%\.nuget\packages\redis-64\”version-number”
The tools directory contains executables for both the server and the command cli. Please read the “Redis on Windows.docx” document in this folder.
Run the Redis server from a console:
```
> cd %HOME%\.nuget\packages\redis-64\”version-number”\tools
> redis-server
```
To start the Redis server from a console:
```
> cd %HOME%\.nuget\packages\redis-64\”version-number”\tools
> redis-server
```
Please read “Windows Service Documentation.docx” in the tools directory on how to setup up Redis to run as a Windows service. Redis is configured in the redis.conf file in the tools directory (such as port, db-file etc.). By default, Redis is only accessible on localhost (for security reasons), it can however be configured for network access as well.

# HOWTO Manage the Redis Database
Redis commands listed at https://redis.io/ and can be executed using the redis-cli or from a client. FOr instance, to connect to a local server:
```
$ redis-cli
redis>
```
To see Redis logs:
```
$ cat /var/log/redis_6379.log
```
To see Redis logs:
```
$ cat /var/log/redis_6379.log
```
To stop Redis server manually
```
$ /etc/init.d/redis-server restart
```
...or…
```
$ redis-cli shutdown
```
Some other useful commands:

|COMMAND|NOTE|RELATED|
|-------|----|-------|
|keys|List all keys||
|flushall|Clear entire DB||
|flushdb|||
|set key value|Set “key” to value “value”||
|get key|Get value for key||
|del key|Delete value for key||
|INCR key|Increment numeric key||
|EXPR key n|Key exists for n seconds|TTL key|
|RPUSH, LPUSH|List operations|LRANGE, LLEN, LPOP, ...||
|SADO, SREM|Set operations|SISMEMBER, SUNION, ...|
|ZADO, ZREM|Sorted (scored) set operations||

# HOWTO Assign QuerySEAD local HTTP port number
QuerySEAD uses a self-hosted HTTP server (Krestel) and the server URL (hostname and port number) is  configured in the “hosting.json” that is located in the application root folder.
{
  "server.urls": "http://localhost:5123"
}
Note! Remember to configure web server reverse proxy to redirect to this URL.
# HOWTO Override local HTTP port number using command line
The server url specified om.
dotnet myapp.dll --urls "http://*:5060;
Note! Remember to configure web server reverse proxy to redirect to this URL.

# HOWTO Start QuerySEAD application (on Debian)
Open command prompt and move to project directory
$ sudo -u www-data dotnet /var/webapps/query_sead/QuerySeadAPI.dll

# HOWTO Enable CORS for the QuerySEAD ASP.NET Core (on Debian)
Use the following Apache virtual host configuration file on Debian. Note that Apache only acts as a reverse proxy to the .NET hosted web server (Krestel).
<VirtualHost *:8089>

        # Reverse Proxy
        ProxyPass "/" "http://localhost:5123/"
        ProxyPassReverse "/"  "http://localhost:5123/"

        # CORS headers
        Header always set Access-Control-Allow-Origin "*"
        Header always set Access-Control-Allow-Methods "POST, GET, OPTIONS, DELETE, PUT"
        Header always set Access-Control-Max-Age "1000"
        Header always set Access-Control-Allow-Headers "x-requested-with, Content-Type, origin, authorization, accept, client-security-token"

        # Handle (intercept) CORS preflight OPTIONS request.
        RewriteEngine On
        RewriteCond %{REQUEST_METHOD} OPTIONS
        RewriteRule ^(.*)$ $1 [R=200,L]
        ...
</VirtualHost>

# HOWTO Deploy QuerySEAD on Dev server
The target deployment folder for testversion of QuerySEAD is currently

The target folder for testversion deployment of QuerySEAD is currently
the-target-folder = /home/roger/applications/publish
Stop the service if it is currently running
ps -ef | grep QuerySead
Delete all files in target folder.
$ sudo rm -rf the-target-folder/*
Copy the new release (content of “publish” folder) to target folder (e.g. WinSCP).
$ sudo rm -rf the-target-folder/
Optional fix: Copy XML
$ sudo cp the-target-folder/../*.xml the-target-folder/
Assign ownership
$ sudo chown -R www-data:www-data /var/webapps/query_sead/publish
Start application
$ sudo -u www-data dotnet /var/webapps/query_sead/QuerySeadAPI.dll

# HOWTO Install Oracle SQL Developer
Modeller requires JDK which can be downloaded from this site
http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html
Download and extract modeller from this link
http://www.oracle.com/technetwork/developer-tools/sql-developer/overview/index.html
Download PostgreSQL JDBC driver from this link
https://jdbc.postgresql.org/download.html
Create a shortcut to the executable “sqldeveloper.exe”, and start the program.
sqldeveloper.exe
Specify location of OpenJDK installed in step 1 if the following popup is displayed:.

Select “Tools - Preferences - Database - 3rd Party JDBC drivers” to install the PostgreSQL JDBC driver downloaded in step 3.
Add connection to PostgrSQL database. See this link if the database dropdown list isn’t populated (manual edit of connection.xml found in ~AppData/SQL Developer/system.../o.jdeveloper.db.connection)


# HOWTO Update Query SEAD API Dependencies
Open Query SEAD API .NET Core project in Visual Studio.

1. Select “Tools - NuGet Package Manager - Manage NuGet Packages for Solution”
2. Select “Updates” and uncheck “Include prereleases” (if checked).

Packages can be installed in batch by checking all packages and then press “Update”, or each in turn by selecting the package and press “Install”.
It might be necessary to consolidate packages after update in tab “Consolidate”.

# HOWTO Configure Query SEAD API
SEAD API configuration  elements are stored in “appsettings.json” which resides in the web project folder:
{
  "Logging": {
    "IncludeScopes": false,
    "LogLevel": {
      "Default": "Debug",
      "System": "Information",
      "Microsoft": "Information"

  },
  "Data": {
    "DefaultConnection": {
      "ConnectionString": ""

  },
  "QueryBuilderSetting": {
    "Facet": {
      "DirectCountTable": "tbl_analysis_entities",
      "DirectCountColumn": "tbl_analysis_entities.analysis_entity_id",
      "IndirectCountTable": "tbl_dating_periods",
      "IndirectCountColumn": "tbl_dating_periods.dating_period_id",
      "ResultQueryLimit": 10000,
      "CategoryNameFilter": true
    },
    "Store": {
      "ConnectionString": "",
      "CacheSeq": "metainformation.file_name_data_download_seq",
      "CacheDir": "/../../api/cache",
      "CurrentViewStateId": 7,
      "ViewStateTable": "metainformation.tbl_view_states",
      "UseRedisCache":  false


}
