#!/bin/bash

set -e  # 在遇到错误时停止执行

# 检查是否以root用户运行
if [ "$(id -u)" -ne 0 ]; then
    echo "请以 root 用户运行此脚本"
    exit 1
fi

# 检查系统类型
if ! grep -qE '^(Rocky|CentOS)' /etc/*release; then
    echo "此脚本仅支持红帽系，例如 Rocky Linux 或 CentOS。"
    exit 1
fi

# 检查软件版本并处理
for package in nginx php mysql-server docker docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
    echo "==================== 检查 $package 版本 ===================="
    if rpm -q "$package" &> /dev/null; then
        echo "$package 已安装，版本为 $(rpm -q "$package")"
        read -p "是否卸载 $package (y/n)? " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            yum remove -y "$package" && echo "$package 已卸载。"
        else
            echo "$package 保留。"
        fi
    fi
done

# 安装 Nginx
echo "==================== 安装 Nginx ===================="
cat <<EOF > /etc/yum.repos.d/nginx.repo
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
yum install -y nginx && systemctl enable --now nginx
echo "Nginx 安装完成！"

# 安装 PHP 8.3
echo "==================== 安装 PHP 8.3 ===================="
yum -y install http://rpms.remirepo.net/enterprise/remi-release-9.rpm
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
yum makecache -y
yum module reset php -y
yum module -y install php:remi-8.3
yum -y install php php-{redis,common,pear,cgi,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap}

# 配置 PHP
echo "正在配置 PHP..."
sed -i -e '/^user/c user = nginx' \
       -e '/^group/c group = nginx' \
       -e '/^listen =/c listen = 127.0.0.1:9000' \
       /etc/php-fpm.d/www.conf
sed -i -e '/^upload_max_filesize =/c upload_max_filesize = 20M' \
       -e '/^post_max_size =/c post_max_size = 20M' \
       /etc/php.ini

systemctl enable --now php-fpm.service
echo "PHP 安装及配置完成！"

# 安装 MySQL 8.4
echo "==================== 安装 MySQL 8.4 ===================="
wget -q https://repo.mysql.com/mysql84-community-release-el9-1.noarch.rpm
rpm -ivh mysql84-community-release-el9-1.noarch.rpm
yum install -y mysql-server && systemctl enable --now mysqld

# 获取临时密码并修改密码
temporary_pass=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
new_pwd="BlogData888#"

if mysqladmin -u root -p"$temporary_pass" password "$new_pwd"; then
    echo "MySQL 密码修改成功！"
else
    echo "修改密码失败，请检查临时密码是否正确。"
    exit 1
fi

# 删除安装包
rm -f mysql84-community-release-el9-1.noarch.rpm

# 创建 WordPress 数据库
db="wp"
mysql -u root -p"$new_pwd" -e "CREATE DATABASE IF NOT EXISTS $db;"
echo "MySQL 安装及配置完成！"

# 下载并解压 WordPress
echo "==================== 下载 WordPress ===================="
mkdir -p /blog && cd /blog
wget -q https://wordpress.org/latest.zip && unzip -q latest.zip && rm -rf latest.zip

# 给 nginx 授权
chown -R nginx:nginx /blog/wordpress/
echo "WordPress 安装完成！"

# 安装最新版 Docker (可选)
# echo "==================== 安装 Docker ===================="
# wget -O /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# tee /etc/docker/daemon.json <<-'EOF'
# {
#   "registry-mirrors": ["https://guixmbxv.mirror.aliyuncs.com"],
#   "data-root": "/data/docker"
# }
# EOF
# systemctl enable --now docker
# echo "Docker 安装完成！"

# 输出安装信息
echo "==================== 安装信息 ===================="
echo "Nginx 版本为最新版"
echo "PHP 版本为：PHP 8.3"
echo "数据库版本为：MySQL 8.4"
echo "WordPress 版本为最新版"
echo "MySQL 数据库密码为: $new_pwd，请尽快修改"
echo "WordPress 数据库名为：$db"
