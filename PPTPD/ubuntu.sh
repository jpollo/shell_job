#!/bin/sh
clear                                                                                           
echo ""
echo "\033[7m"
echo "+---------------------------------------------------------------------+"    
echo "+                                                                     +"    
echo "+          PPTP/L2TP/OPENVPN + Freeradius + Mysql package             +"
echo "+                                                                     +"    
echo "+          Author: Palfans (palfans@gmail.com)                        +"    
echo "+          Modify: princehaku (baizhongwei@gmail.com)                 +"    
echo "+          Platform: Ubuntu 10.04 LTS                                 +"    
echo "+                                                                     +"    
echo "+---------------------------------------------------------------------+"
echo "\033[0m"
echo

#set -x

# set the source url
platform=`uname -i`
if [ $platform = "unknown" ]; then
  platform="i386"
fi

# set clients ip address
# pptp, local_ip is the server ip, remote_id is the range of client
p_local_ip="192.168.77.1"
p_remote_ip="192.168.77.50-200"

#openvpn, local_ip is the client ip subnet
o_local_ip="192.168.88.0"

# l2tp, local_ip is the server ip, remote_id is the range of client
l_local_ip="192.168.99.1"
l_remote_ip="192.168.99.100-192.168.99.200"

# parameters
wd=`pwd`
wd_work=$wd
server_ip=`ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk 'NR==1 { print $1}'`
mysql_root_pwd="123456"
mysql_radius_pwd="123456"

# secret key is used to replace all the secret keys
secret_key="techest"

# dir path
nginx_html="/var/www/nginx-default"
radius_dir="/etc/freeradius"
etc_dir="/etc"
sbin_dir="/usr/sbin"

get_char()
{
  SAVEDSTTY=`stty -g`
  stty -echo
  stty cbreak
  dd if=/dev/tty bs=1 count=1 2> /dev/null
  stty -raw
  stty echo
  stty $SAVEDSTTY
}

init()
{
  echo ""
  echo "Please input server ip:"
  read -p "(Default ip: $server_ip):" temp
  if [ "$temp" != "" ]; then
    server_ip=$temp
  fi
  echo ""
  echo "Please input the root password of Mysql:"
  read -p "(Default password: $mysql_root_pwd):" temp
  if [ "$temp" != "" ]; then
    mysql_root_pwd=$temp
  fi
  echo ""
  echo "Please input the radius password of Mysql:"
  read -p "(Default password: $mysql_radius_pwd):" temp
  if [ "$temp" != "" ]; then
    mysql_radius_pwd=$temp
  fi
  
  mkdir -p $wd_work
  
  echo ""
  echo "\033[5mPress any key to continue...\033[0m"
  get_char
  clear
}

install_mysql()
{
  echo "+--------------------------------------+"
  echo "+          install mysql               +"
  echo "+--------------------------------------+"
  ret=`dpkg -l|grep mysql-server|wc -l`
  if [ $ret = "0" ]; then
    cd $wd_work
    sed -e "s/mysql_root_pwd/$mysql_root_pwd/g" $wd_work/mysql.txt > $wd_work/mysql.txt.mod
    debconf-set-selections $wd_work/mysql.txt.mod
    apt-get install -y mysql-server mysql-client
    sed -i -e "s/skip-external-locking/skip-external-locking\nskip-innodb/" /etc/mysql/my.cnf
    service mysql restart
    sed -i -e "4c service mysql start" /etc/rc.local
  fi
}

install_nginx_php()
{
  echo "+--------------------------------------+"
  echo "+          install nginx               +"
  echo "+--------------------------------------+"
  ret=`dpkg -l|grep nginx|wc -l`
  if [ $ret = "0" ]; then
    cd $wd_work
    apt-get install -y nginx spawn-fcgi
    echo "+--------------------------------------+"
    echo "+          install php                 +"
    echo "+--------------------------------------+"
    apt-get install -y php5-common php5-cgi php5-mysql php5-curl php5-gd php5-idn php-pear php5-imagick php5-imap php5-mcrypt php5-memcache php5-ming php5-ps php5-pspell php5-recode php5-snmp php5-sqlite php5-tidy php5-xmlrpc php5-xsl php-db
    
    echo "+--------------------------------------+"
    echo "+    install php support for nginx     +"
    echo "+--------------------------------------+"
    /usr/bin/spawn-fcgi -f /usr/bin/php-cgi -a 127.0.0.1 -p 9000 -P /var/run/fastcgi-php.pid
    sed -i -e "2c /usr/bin/spawn-fcgi -f /usr/bin/php-cgi -a 127.0.0.1 -p 9000 -P /var/run/fastcgi-php.pid" /etc/rc.local
    cp -f $nginx_html/index.html $nginx_html/index.html.bak
    cp -f $wd_work/nginx-sites-default /etc/nginx/sites-enabled/default
  
cat > $nginx_html/index.html <<EOF
<title>Test Server</title>
This is a test server.
EOF

cat > $nginx_html/phpinfo.php <<EOF
<?php
phpinfo();
?>
EOF
    service nginx restart
  fi
}

install_phpmyadmin()
{
  echo "+--------------------------------------+"
  echo "+         install phpMyAdmin           +"
  echo "+--------------------------------------+"
  ret=`find / -name "phpmyadmin.css.php"|wc -l`
  if [ $ret = "0" ]; then
    cd $wd_work
    source_name="phpMyAdmin-3.3.7-all-languages.tar.gz"
    tar xf $wd_work/$source_name
    mkdir -p $nginx_html/pma
    cp -Rf $wd_work/`basename $source_name .tar.gz`/* $nginx_html/pma/
    cp -f $nginx_html/pma/config.sample.inc.php $nginx_html/pma/config.inc.php
    sed -i -e "s/blowfish_secret'] = ''/blowfish_secret'] = '$secret_key'/" $nginx_html/pma/config.inc.php
  fi
}

install_freeradius()
{
  echo "+--------------------------------------+"
  echo "+         install freeradius           +"
  echo "+--------------------------------------+"
  ret=`dpkg -l|grep freeradius|wc -l`
  if [ $ret = "0" ]; then
    cd $wd_work
    apt-get install -y freeradius freeradius-ldap freeradius-mysql freeradius-krb5 libgcrypt11-dev
    
    sed -i -e "s/testing123/$secret_key/g" $radius_dir/clients.conf
    sed -i -e "s/radpass/$mysql_radius_pwd/" $radius_dir/sql/mysql/admin.sql
    sed -i -e "s/localhost/127.0.0.1/" $radius_dir/sql/mysql/admin.sql
    sed -i -e "s/radpass/$mysql_radius_pwd/" $radius_dir/sql.conf
    sed -i -e 's/server = "localhost"/server = "127.0.0.1"/' $radius_dir/sql.conf
    sed -i -e 's/^#[ \t]$INCLUDE *sql.conf$/$INCLUDE sql.conf/' $radius_dir/radiusd.conf
    sed -i -e 's/^#[ \t]*sql$/sql/' $radius_dir/sites-available/default
    echo "create database radius;" | mysql --user=root --password=$mysql_root_pwd
    echo "REVOKE ALL PRIVILEGES ON `radius` . * FROM 'radius'@'127.0.0.1';" | mysql --user=root --password=$mysql_root_pwd
		echo "GRANT ALL PRIVILEGES ON `radius` . * TO 'radius'@'127.0.0.1' WITH GRANT OPTION ;" | mysql --user=root --password=$mysql_root_pwd
    mysql --user=root --password=$mysql_root_pwd < $radius_dir/sql/mysql/admin.sql
    mysql --user=root --password=$mysql_root_pwd radius < $radius_dir/sql/mysql/schema.sql
    mysql --user=root --password=$mysql_root_pwd radius < $radius_dir/sql/mysql/ippool.sql
    mysql --user=root --password=$mysql_root_pwd radius < $radius_dir/sql/mysql/nas.sql
    mysql --user=root --password=$mysql_root_pwd radius < $radius_dir/sql/mysql/cui.sql
    mysql --user=root --password=$mysql_root_pwd radius < $radius_dir/sql/mysql/wimax.sql

cat > $wd_work/w.sql <<EOF
INSERT INTO radcheck (id, username, attribute, op, value) VALUES (1, 'test', 'Cleartext-Password', ':=', '123456');
EOF

    mysql --user=root --password=$mysql_root_pwd radius < $wd_work/w.sql
    
    service freeradius restart
  fi
}

install_daloradius()
{
  echo "+--------------------------------------+"
  echo "+         install daloradius           +"
  echo "+--------------------------------------+"
  ret=`find / -name "mng-rad-groups.php"|wc -l`
  if [ $ret = "0" ]; then
    cd $wd_work
    source_name="daloradius-0.9-8.tar.gz"
    tar xf $source_name
    cp -Rf `basename $source_name .tar.gz` $nginx_html/dr
    mysql --user=root --password=$mysql_root_pwd radius < $nginx_html/dr/contrib/db/mysql-daloradius.sql
    mv $nginx_html/dr/library/daloradius.conf.php $nginx_html/dr/library/daloradius.conf.php.ori
    cp -f daloradius.conf.php $nginx_html/dr/library/daloradius.conf.php
    nginx_html_t=$(echo "$nginx_html" | sed 's/\//\\\//g')
    radius_dir_t=$(echo "$radius_dir" | sed 's/\//\\\//g')
    sed -i -e "s/nginx_html/$nginx_html_t/" $nginx_html/dr/library/daloradius.conf.php
    sed -i -e "s/radius_dir/$radius_dir_t/" $nginx_html/dr/library/daloradius.conf.php
    sed -i -e "s/secret_key/$secret_key/" $nginx_html/dr/library/daloradius.conf.php
    sed -i -e "s/mysql_radius_pwd/$mysql_radius_pwd/" $nginx_html/dr/library/daloradius.conf.php
    echo "delete from radius.operators where username='liran';" | mysql --user=root --password=$mysql_root_pwd radius
  fi
}

install_pptp()
{
  echo "+--------------------------------------+"
  echo "+          install pptp                +"
  echo "+--------------------------------------+"
  ret=`dpkg -l|grep pptpd|wc -l`
  if [ $ret = "0" ]; then
    cd $wd_work
    apt-get install -y pptpd ppp
  
cat >>/etc/pptpd.conf<<EOF
localip $p_local_ip
remoteip $p_remote_ip
EOF
  
    echo "+--------------------------------------+"
    echo "+    install radiusclient for pptp     +"
    echo "+--------------------------------------+"
    
    etc_dir_t=$(echo "$etc_dir" | sed 's/\//\\\//g')
    sbin_dir_t=$(echo "$sbin_dir" | sed 's/\//\\\//g')
    cp -R $wd_work/radiusclient $etc_dir/radiusclient
    cp -f $etc_dir/radiusclient/radiusclient.conf.in $etc_dir/radiusclient/radiusclient.conf
    sed -i -e "s/@etcdir@/$etc_dir_t/" $etc_dir/radiusclient/radiusclient.conf
    sed -i -e "s/@etcdir@/$etc_dir_t/" $etc_dir/radiusclient/dictionary
    sed -i -e "s/@sbindir@/$sbin_dir_t/" $etc_dir/radiusclient/radiusclient.conf
  
cat >> $etc_dir/radiusclient/servers<<EOF
127.0.0.1 $secret_key
EOF

    sed -i -e 's/^#ms-dns 10.0.0.1$/ms-dns 8.8.8.8/' /etc/ppp/pptpd-options
    sed -i -e 's/^#ms-dns 10.0.0.2$/ms-dns 8.8.4.4/' /etc/ppp/pptpd-options
    radius_so=`find /usr -name radius.so`
  
cat >> /etc/ppp/pptpd-options <<EOF
plugin $radius_so
radius-config-file $etc_dir/radiusclient/radiusclient.conf
EOF
  
    service pptpd restart
  fi
}

install_openvpn()
{
  echo "+--------------------------------------+"
  echo "+          install openvpn             +"
  echo "+--------------------------------------+"
  ret=`dpkg -l|grep openvpn|wc -l`
  if [ $ret = "0" ]; then
    cd $wd_work
    apt-get install -y openvpn
    
    key_path=$wd/openvpn/easy-rsa/keys
    key_path=$(echo "$key_path" | sed 's/\//\\\//g')
    mkdir $wd/openvpn
    cp -R /usr/share/doc/openvpn/examples/easy-rsa/2.0 $wd/openvpn/easy-rsa
    cp -f $wd_work/openvpn-server.conf /etc/openvpn/server.conf
    sed -i -e "s/key_path/$key_path/g" /etc/openvpn/server.conf
    sed -i -e "s/@server_ip@/$o_local_ip/g" /etc/openvpn/server.conf
    cp -f $wd_work/vars $wd/openvpn/easy-rsa
    cd $wd/openvpn/easy-rsa
    . ./vars
    ./clean-all --batch
    ./build-ca --batch
    ./build-key-server --batch server
    ./build-dh --batch
    
    cd $wd/openvpn
    mkdir client
    cd $wd
    cp -f $wd_work/openvpn-client.ovpn $wd/openvpn/client/client.ovpn
    sed -i -e "s/server_ip/$server_ip/g" $wd/openvpn/client/client.ovpn
    cp -f $wd/openvpn/easy-rsa/keys/ca.crt $wd/openvpn/client/
    
    echo "+--------------------------------------+"
    echo "+   install radiusplugin for openvpn   +"
    echo "+--------------------------------------+"
    cd $wd_work
    source_name="radiusplugin_v2.1_beta9.tar.gz"
    tar xf $source_name
    cd radiusplugin
    make
    cp radiusplugin.so /etc/openvpn/
    sed -i -e "s/sharedsecret=testpw/sharedsecret=$secret_key/" radiusplugin.cnf
    cp radiusplugin.cnf /etc/openvpn/
    
    service openvpn restart
  fi
}


set_iptables()
{
  echo "+--------------------------------------+"
  echo "+          iptables setting            +"
  echo "+--------------------------------------+"
  apt-get install -y iptables
  sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" /etc/sysctl.conf

cat >> /etc/sysctl.conf <<EOF
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
EOF

  sysctl -p
  
  iptables -A INPUT -i tun+ -j ACCEPT
  iptables -A FORWARD -i tun+ -j ACCEPT
  iptables -A INPUT -i tap+ -j ACCEPT
  iptables -A FORWARD -i tap+ -j ACCEPT
  iptables -A INPUT -p udp -d $server_ip --dport 500 -j ACCEPT
  iptables -A INPUT -p udp -d $server_ip --dport 4500 -j ACCEPT
  iptables -A INPUT -p udp -d $server_ip --dport 1701 -j ACCEPT
  iptables -t nat -A POSTROUTING -s 192.168.77.0/24 -j MASQUERADE -o eth0
  iptables -t nat -A POSTROUTING -s 192.168.88.0/24 -j MASQUERADE -o eth0
  iptables -t nat -A POSTROUTING -s 192.168.99.0/24 -j MASQUERADE -o eth0
  iptables -t nat -A POSTROUTING -s 192.168.77.0/24 -j SNAT --to-source $server_ip
  iptables -t nat -A POSTROUTING -s 192.168.88.0/24 -j SNAT --to-source $server_ip
  iptables -t nat -A POSTROUTING -s 192.168.99.0/24 -j SNAT --to-source $server_ip
  iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination 8.8.8.8
  iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination 8.8.4.4
  
  iptables-save > /etc/iptables-rules
  #sed '/auto eth0/a\pre-up iptables-restore < /etc/iptables-rules' /etc/network/interfaces > /etc/network/interfaces.tmp
  #mv /etc/network/interfaces.tmp /etc/network/interfaces
	sed -i -e "5c iptables-restore < /etc/iptables-rules" /etc/rc.local
  for each in /proc/sys/net/ipv4/conf/*
  do
    echo 0 > $each/accept_redirects
    echo 0 > $each/send_redirects
  done
}

check_status()
{
  if [ $# -eq 1 ]; then
    ret=`ps -ef|grep $1|grep -v grep|wc -l`
    if [ $ret = "0" ]; then
      echo "$1\t\t\t[\033[31;5;1m Failed \033[0m]"
    else
      echo "$1\t\t\t[\033[1m OK \033[0m]"
    fi
  fi
  
  if [ $# -eq 2 ]; then
    ret=`ps -ef|grep $1|grep $2|grep -v grep|wc -l`
    if [ $ret = "0" ]; then
      echo "$1($2)\t\t\t[\033[31;5;1m Failed \033[0m]"
    else
      echo "$1($2)\t\t\t[\033[1m OK \033[0m]"
    fi
  fi
}

usage()
{
  option="1"
  echo "Now you can intall vpn software as below:"
  echo "1. pptp"
  echo "2. openvpn"
  echo "3. all"
  echo ""
  echo "Please input your option:"
  read -p "(Default option: $option):" temp
  if [ "$temp" != "" ]; then
    option=$temp
  fi
}

base_setup()
{
  install_mysql
  install_nginx_php
  install_phpmyadmin
  install_freeradius
  install_daloradius
  set_iptables
  check_status mysql
  check_status nginx
  check_status php
  check_status freeradius
}

# root privilege is mandatory
if [ $(id -u) -ne 0 ]; then
  echo "Error: You must get root privilege at first."
  exit 1
fi

option=$1

if [ $# -ne 1 ]; then
	usage
fi

while [ $option != "1" -a $option != "2" -a $option != "3" -a $option != "4" ]
do
  usage
done

echo "+--------------------------------------+"
echo "+    check accessibility of source     +"
echo "+--------------------------------------+"

echo "+--------------------------------------+"
echo "+    Update source list and init       +"
echo "+--------------------------------------+"
apt-get update
apt-get -y -qq dist-upgrade
apt-get install -y gcc g++ make gawk libxml2-dev libncurses5-dev doxygen debconf-utils unzip
init

cd $wd_work
tar xf $wd_work/install.tar.gz

base_setup

if [ $option = "1" ]; then
  install_pptp
  check_status pptpd
fi

if [ $option = "2" ]; then
  install_openvpn
  check_status openvpn
fi

if [ $option = "3" ]; then
  install_openvpn
  install_pptp
  check_status pptpd
  check_status openvpn
fi

rm -Rf $wd_work
