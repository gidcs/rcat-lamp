#!/bin/bash
# RCAT LAMP Stack for CentOS
# https://github.com/gidcs/rcat-lamp
# rcat.sh

function echoline {
  echo "========================================================================="
}

function wget_file {
  target_file=$1
  req_url=$2
  wget -O ${target_file} -c "${req_url}"
  if [ ! -f ${target_file} ]; then
    echo "Error: ${target_file} download failed."
    exit 1
  fi
}

function restart_service {
  service $1 restart
  if [ "$?" -ne 0 ]; then
    echo "Error: $1 restart failed"
    exit 1
  fi
}

function allow_incoming_tcp_port {
  if [ "$iptables" = "y" ]; then
    iptables -A INPUT -p tcp --dport $1 -j ACCEPT
    iptables -A OUTPUT -p tcp --sport $1 -j ACCEPT
    service iptables save
  fi
}

function allow_incoming_tcp_multiport {
  if [ "$iptables" = "y" ]; then
    iptables -A INPUT -p tcp -m multiport --dports $1 -j ACCEPT
    iptables -A OUTPUT -p tcp -m multiport --sports $1 -j ACCEPT
    service iptables save
  fi
}

function allow_outgoing_tcp_port {
  if [ "$iptables" = "y" ]; then
    iptables -A OUTPUT -p tcp --dport $1 -j ACCEPT
    iptables -A INPUT -p tcp --sport $1 -j ACCEPT
    service iptables save
  fi
}

function allow_outgoing_tcp_multiport {
  if [ "$iptables" = "y" ]; then
    iptables -A OUTPUT -p tcp -m multiport --dports $1 -j ACCEPT
    iptables -A INPUT -p tcp -m multiport --sports $1 -j ACCEPT
    service iptables save
  fi
}

function allow_outgoing_udp_port {
  if [ "$iptables" = "y" ]; then
    iptables -A OUTPUT -p udp --dport $1 -j ACCEPT
    iptables -A INPUT -p udp --sport $1 -j ACCEPT
    service iptables save
  fi
}

function root_check {
  # Check if user is root
  if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, use sudo $0."
    exit -1
  fi
}

function os_check {
  # Check if CentOS 6
  if [ ! -e '/etc/redhat-release' ]; then
    echo 'Error: sorry, we currently support CentOS 6 only.'
    exit -1
  fi
}

function version_check {
  #get version
  uname=`uname -i`
  version=`grep -o "[0-9]" /etc/redhat-release | head -n1`
  if [ "$version" -ne '6' ]; then
    echo 'Error: sorry, we currently support CentOS 6 only.'
    exit -1
  fi
}

function msg_before_installation {
  clear
  echo ""
  echo "RCAT LAMP Stack for CentOS"
  echoline
  echo "RCAT is a yum based solution to install LAMP development environment"
  echo "For more information, please visit https://github.com/gidcs/rcat-lamp"
  echo ""
  echo "Any key to continue"
  echoline
  read -n 1
}

function prev_installation {
  root_check
  os_check
  version_check
  msg_before_installation
  #mkdir home directory
  mkdir -p /home
}


function ask_iptables {
  if [ "$iptables" = "" ]; then
    read -p "Flush and reapply iptables rules (n,y): " iptables
    re='^[Nn]'
    if [[ $iptables =~ $re ]]; then
      echo "The iptables rules will not be applied!!"
    else
      iptables="y"
      echo "The iptables rules will be applied!!"
    fi
  fi
}

function ask_servername {
  while [ "$servername" = "" ]
  do
    read -p "Server Name: " servername
    if [ "$servername" = "" ]; then
      echo "Error: Server Name Can't be empty!!"
    fi
  done
}

function ask_adminemail {
  while [ "$adminemail" = "" ]
  do
	  read -p "Administrator Email: " adminemail
	  if [ "$adminemail" = "" ]; then
		  echo "Error: Administrator Email Can't be empty!!"
	  fi
  done
}

function ask_mysqlrootpwd {
  while [ "$mysqlrootpwd" = "" ]
  do
    read -p "MySQL Root Password: " mysqlrootpwd
    if [ "$mysqlrootpwd" = "" ]; then
      echo "Error: MySQL Root Password Can't be empty!!"
    fi
  done
}

function ask_sshport {
  while [ "$sshport" = "" ]
  do
    read -p "Change your SSH port number(default:22): " sshport
    re='^[0-9]+$'
    if ! [[ $sshport =~ $re ]] ; then
      if [ "$sshport" = "" ]; then
        sshport="22"
      else
        echo "You are recommended to use a port number >= 1024"
        sshport=""
      fi
    else
      if [ "$sshport" = "" ]; then
        sshport="22"
      elif [ "$sshport" -le "1023" ]; then
        echo "You are recommended to use a port number >= 1024"
        sshport=""
      fi
    fi
  done
}

function ask_information {
  #ask for some information
  ask_servername
  ask_adminemail
  ask_mysqlrootpwd
  ask_sshport
  ask_iptables
  clear
  echoline
  echo "Your Configuration"
  echoline
  echo "servername: "$servername
  echo "adminemail: "$adminemail
  echo "mysqlrootpwd: "$mysqlrootpwd
  echo "sshport: "$sshport
  echo "iptables: "$iptables
  echoline
}

function change_hostname {
  #change hostname
  sed -i '/HOSTNAME/d' /etc/sysconfig/network
  echo "HOSTNAME=$servername" >> /etc/sysconfig/network
  echo "127.0.0.1 $servername" >> /etc/hosts
  hostname $servername
  service network restart
  if [ "$?" -ne 0 ]; then
    echo "Error: network restart failed"
    exit -1
  fi
}


function change_sshport {
  #change sshd port
  if [ "$current_sshport" = "" ]; then
    sed -i 's/#Port 22/Port '$sshport'/g' /etc/ssh/sshd_config
  else
    sed -i 's/Port '$current_sshport'/Port '$sshport'/g' /etc/ssh/sshd_config
  fi
  
  allow_incoming_tcp_port $sshport
  if [ "$iptables" = "y" ]; then
    restart_service iptables
  fi
  service sshd restart
  if [ "$?" -ne 0 ]; then
    echo "Error: sshd restart failed"
    exit -1
  fi
}

function update_check {
  yum update -y
}

function install_epel-release {
  yum install epel-release -y
}

function install_basic_env {
  yum install unzip bzip2 gcc libcap libcap-devel expect openssl at vim screen git -y
}

function install_ntpd {
  yum install ntp -y
  service ntpd start
  chkconfig ntpd on
  allow_outgoing_udp_port 123
}

function install_iptables {
  if [ "$iptables" = "y" ]; then
    yum install iptables -y
    
    # Flushing all rules
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F
    
    # make allow all current connections to make them stay online
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Allow current ssh port to make it stay online
    current_sshport=`grep ^Port /etc/ssh/sshd_config | awk '{ print $2 }'`
    if [ "$current_sshport" = "" ]; then
      allow_incoming_tcp_port 22
    else
      allow_incoming_tcp_port $current_sshport
    fi
    
    # Set Default Chain Policies
    iptables -P INPUT DROP
    iptables -P OUTPUT DROP
    iptables -P FORWARD DROP
    
    # Prevent attack
    iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
    iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
    
    # Drop Invalid Packets
    iptables -A INPUT -m state --statestate --state INVALID -j DROP

    # Allow Loopback Connections
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Allow incoming ping
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT
    
     # Allow outgoing ping
    iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

    # Allow outgoing dns
    allow_outgoing_tcp_port 53
    allow_outgoing_udp_port 53
    
    # Allow outgoing traceroute
    allow_outgoing_udp_port 33434:33523
    
    # Allow outgoing http/https, smtp/smtps, imap/imaps, pop3/pop3s, ftp/ftps
    allow_outgoing_tcp_multiport 25,465,587
    allow_outgoing_tcp_multiport 80,443
    allow_outgoing_tcp_multiport 143,993
    allow_outgoing_tcp_multiport 110,995
    allow_outgoing_tcp_multiport 20,21
    
    
    restart_service iptables
    chkconfig iptables on
  fi
}

function install_rcat_env {
  mkdir -p /etc/rcat  
  wget_file /etc/rcat/rcat.zip https://raw.githubusercontent.com/gidcs/rcat-lamp/master/rcat.zip
  cd /etc/rcat
  unzip -o rcat.zip
  cd -
}

function install_mariadb {
  if [ "$uname" == "x86_64" ]; then
    mariadb_arch="amd64"
  else
    mariadb_arch="x86"
  fi
  cat > /etc/yum.repos.d/MariaDB.repo <<EOF
# MariaDB 10.1 CentOS repository list - created 2016-10-17 09:45 UTC
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos6-${mariadb_arch}
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1  
EOF
  yum install MariaDB-server MariaDB-client -y
  chkconfig mysql on
  #start mysql and first configuration
  \cp /etc/my.cnf /etc/my.cnf.backup
  \cp /etc/rcat/my.cnf /etc/my.cnf
  restart_service mysql
  mysqladmin -u root password $mysqlrootpwd
  cat > /tmp/mysql_sec_script<<EOF
use mysql;
update user set password=password('$mysqlrootpwd') where user='root';
delete from user where not (user='root') ;
delete from user where user='root' and password='';
drop database test;
DROP USER ''@'%';
flush privileges;
EOF
  mysql -u root -p$mysqlrootpwd -h localhost < /tmp/mysql_sec_script
  rm -f /tmp/mysql_sec_script
  sed -i 's/your_password/'$mysqlrootpwd'/g' /etc/my.cnf
  restart_service mysql
}


function install_apache {
  # install apache
  yum install httpd httpd-devel -y
  install_mod_ruid2
  #write configuration file
  \cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.backup
  sed -i 's/Include conf\.d\/\*\.conf/#Include conf\.d\/\*\.conf/g' /etc/httpd/conf/httpd.conf
  sed -i 's/IncludeOptional conf\.d\/\*\.conf/#IncludeOptional conf\.d\/\*\.conf/g' /etc/httpd/conf/httpd.conf
  sed -i '/<IfModule prefork.c>/,/<\/IfModule>/d' /etc/httpd/conf/httpd.conf
  sed -i '/<IfModule worker.c>/,/<\/IfModule>/d' /etc/httpd/conf/httpd.conf
  echo "ServerName $servername" >> /etc/httpd/conf/httpd.conf
  echo 'Include conf/extra/localhost.ip.conf' >> /etc/httpd/conf/httpd.conf
  echo 'Include conf/extra/httpd-mpm.conf' >> /etc/httpd/conf/httpd.conf
  echo 'Include conf.d/*.conf' >> /etc/httpd/conf/httpd.conf
  mkdir -p /etc/httpd/conf/extra
  \cp /etc/rcat/httpd-mpm.conf /etc/httpd/conf/extra/httpd-mpm.conf
  \cp /etc/rcat/localhost.ip.conf /etc/httpd/conf/extra/localhost.ip.conf
  sed -i 's/localhost/'$servername'/g' /etc/httpd/conf/extra/localhost.ip.conf
  sed -i 's/webmaster@example.com/'$adminemail'/g' /etc/httpd/conf/extra/localhost.ip.conf
  groupadd webapps
  #-r system account which doesn't have password
  #-M do not create directory
  useradd -g webapps -n -r -M -s /sbin/nologin -d /var/www/html webapps
  mkdir -p /var/www/log
  mkdir -p /var/www/html
  cd /var/www/html/
  \cp /etc/rcat/default.zip /var/www/html/default.zip
  unzip -o default.zip;
  rm -f default.zip;
  cd -
  chown -R webapps:webapps /var/www/html/
  restart_service httpd
  allow_incoming_tcp_multiport 80,443
}

function install_php {
  #install webtatic repo
  wget_file latest.rpm https://mirror.webtatic.com/yum/el6/latest.rpm
  rpm -Uvh latest.rpm
  
  yum install php56w php56w-opcache php56w-common php56w-devel -y 
  yum install php56w-mysql php56w-pdo -y
  yum install php56w-gd php56w-mbstring php56w-mcrypt php56w-bcmath php56w-xml php56w-imap php56w-ldap -y
  yum install yum-plugin-replace -y
  yum install php56w-pear -y
  yum replace php-common --replace-with=php56w-common
  
  # pear install --alldeps Mail
  
  #configure php
  sed -i 's/post_max_size = 8M/post_max_size = 50M/g' /etc/php.ini
  sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 50M/g' /etc/php.ini
  sed -i 's/max_execution_time = 30/max_execution_time = 300/g' /etc/php.ini
}

function install_mod_ruid2 {
  # install mod_ruid2
  wget_file mod_ruid2.tar.bz2 http://sourceforge.net/projects/mod-ruid/files/latest/download
  tar xvjf mod_ruid2.tar.bz2
  cd mod_ruid2-*
  apxs -a -i -l cap -c mod_ruid2.c
  cd -
  rm -rf mod_ruid2*
}

function install_ioncube {
  #install ioncube
  if [ "$uname" == "x86_64" ]; then
    wget_file ioncube_loaders_lin_x86-64.tar.gz http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
    tar xzvf ioncube_loaders_lin_x86-64.tar.gz
    PHP_VERSION="`php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;"`"
    cp "ioncube/ioncube_loader_lin_${PHP_VERSION}.so" /usr/lib64/php/modules
    echo "; Enable ioncube loader" >> /etc/php.d/ZendGuard.ini
    echo " zend_extension=/usr/lib64/php/modules/ioncube_loader_lin_${PHP_VERSION}.so" >> /etc/php.d/ZendGuard.ini
  else
    wget_file ioncube_loaders_lin_x86.tar.gz http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86.tar.gz
    tar xzvf ioncube_loaders_lin_x86.tar.gz
    PHP_VERSION="`php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;"`"
    cp "ioncube/ioncube_loader_lin_${PHP_VERSION}.so" /usr/lib/php/modules
    echo "; Enable ioncube loader" >> /etc/php.d/ZendGuard.ini
    echo " zend_extension=/usr/lib/php/modules/ioncube_loader_lin_${PHP_VERSION}.so" >> /etc/php.d/ZendGuard.ini
  fi
  rm -rf ioncube*
}

function install_zend_guard_loader { 
  #install zendguard
  if [ "$uname" == "x86_64" ]; then
    wget_file zend-loader-php5.6-linux-x86_64.tar.gz http://downloads.zend.com/guard/7.0.0/zend-loader-php5.6-linux-x86_64.tar.gz
    tar xzvf zend-loader-php5.6-linux-x86_64.tar.gz
    cp zend-loader-php5.6-linux-x86_64/ZendGuardLoader.so /usr/lib64/php/modules
    echo "; Enable Zend Guard extension" >> /etc/php.d/ZendGuard.ini
    echo "zend_extension=/usr/lib64/php/modules/ZendGuardLoader.so" >> /etc/php.d/ZendGuard.ini
    echo "zend_loader.enable=1" >> /etc/php.d/ZendGuard.ini
  else
    wget_file zend-loader-php5.6-linux-i386.tar.gz http://downloads.zend.com/guard/7.0.0/zend-loader-php5.6-linux-i386.tar.gz
    tar xzvf zend-loader-php5.6-linux-i386.tar.gz
    cp zend-loader-php5.6-linux-i386/ZendGuardLoader.so /usr/lib/php/modules
    echo "; Enable Zend Guard extension" >> /etc/php.d/ZendGuard.ini
    echo "zend_extension=/usr/lib/php/modules/ZendGuardLoader.so" >> /etc/php.d/ZendGuard.ini
    echo "zend_loader.enable=1" >> /etc/php.d/ZendGuard.ini
  fi
  rm -rf zend-loader-php5.6*
}

function install_mod-pagespeed {
  #install mod-pagespeed
  if [ "$uname" == "x86_64" ]; then
    wget_file mod-pagespeed-stable_current_x86_64.rpm https://dl-ssl.google.com/dl/linux/direct/mod-pagespeed-stable_current_x86_64.rpm
    rpm -U mod-pagespeed-stable_current_x86_64.rpm
  else
    wget_file mod-pagespeed-stable_current_i386.rpm https://dl-ssl.google.com/dl/linux/direct/mod-pagespeed-stable_current_i386.rpm
    rpm -U mod-pagespeed-stable_current_i386.rpm
  fi
  rm -rf mod-pagespeed*
  restart_service httpd
}

function install_phpmyadmin {
  #install phpmyadmin
  wget_file phpMyAdmin.zip https://files.phpmyadmin.net/phpMyAdmin/4.6.4/phpMyAdmin-4.6.4-all-languages.zip
  unzip phpMyAdmin.zip
  mv phpMyAdmin-* /home/phpMyAdmin
  rm -f phpMyAdmin.zip
  \cp /etc/rcat/config.inc.php /home/phpMyAdmin/config.inc.php
  sed -i 's/GIDCSNET/GIDCS.Net'$RANDOM'GuyuSoftware.Com/g' /home/phpMyAdmin/config.inc.php
  mkdir /home/phpMyAdmin/upload/
  mkdir /home/phpMyAdmin/save/
  #\cp /etc/httpd/conf.d/phpMyAdmin.conf /etc/httpd/conf.d/phpMyAdmin.conf.backup
  #sed -i '/<Directory \/usr\/share\/phpMyAdmin\/>/,/<\/Directory>/d' /etc/httpd/conf.d/phpMyAdmin.conf
  \cp /etc/rcat/phpMyAdmin.conf /etc/httpd/conf.d/phpMyAdmin.conf
  groupadd phpmyadmin
  useradd -g phpmyadmin -n -r -M -s /sbin/nologin -d /home/phpMyAdmin phpmyadmin
  chown -R phpmyadmin:phpmyadmin /home/phpMyAdmin/
  restart_service httpd
}

function install_postfix {
  yum install postfix -y
  restart_service postfix
  chkconfig postfix on
}

function install_proftpd {
  #install proftpd
  yum install proftpd -y
  sed -i 's/ProFTPD server/'$servername'/g' /etc/proftpd.conf
  sed -i 's/root@localhost/'$adminemail'/g' /etc/proftpd.conf
  sed -i -E "/DefaultRoot/a\
  PassivePorts 35000 35999" /etc/proftpd.conf
  restart_service proftpd
  allow_incoming_tcp_port 35000:35999
  allow_incoming_tcp_multiport 20,21
  chkconfig proftpd on 
}

function install_denyhosts {
  #install denyhosts
  yum install denyhosts -y
  sed -i 's/ADMIN_EMAIL = root/ADMIN_EMAIL = '$adminemail'/g' /etc/denyhosts.conf
  restart_service denyhosts
  chkconfig denyhosts on
}

function install_vhost {
  #get vhost.sh
  chmod 755 /etc/rcat/vhost.sh
  ln -s /etc/rcat/vhost.sh /usr/bin/vhost
}

function install_rc {
  cd ~
  git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
  echo | echo | vim +PluginInstall +qall &>/dev/null
  cp /etc/rcat/root.zip ~
  unzip -o root.zip
  rm -f root.zip
  cd -
}

function finish_info {
  #installation finish
  clear
  echo ""
  echo "RCAT LAMP Stack for CentOS"
  echoline
  echo "Installation is finished."
  echo "For more information, please visit https://github.com/gidcs/rcat-lamp"
  echo ""
  echo 'create your VirtualHost with "vhost"'
  echoline
  echo ""
}

function start_installation {
  change_hostname
  update_check
  install_epel-release
  install_basic_env
  install_ntpd
  install_iptables
  install_rcat_env
  install_mariadb
  install_apache
  install_php
  install_ioncube
  install_zend_guard_loader
  install_mod-pagespeed
  install_phpmyadmin
  install_postfix
  install_proftpd
  install_denyhosts
  install_vhost
  install_rc
  change_sshport
}



prev_installation
ask_information
start_installation
finish_info
