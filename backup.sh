#!/bin/bash

# 设置目录和文件名
SOURCE_DIR="/wordpress"
DEST_DIR="/root/backup"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BLOG_BACKUP_FILE="$DEST_DIR/blog_backup_$TIMESTAMP.tar.gz"
DB_BACKUP_FILE="$DEST_DIR/db_backup_$TIMESTAMP.sql"

# 创建备份目录（如果不存在）
mkdir -p "$DEST_DIR"

# 打包并压缩 WordPress 文件，保留目录结构
tar -czf "$BLOG_BACKUP_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"

# 备份 MySQL 数据库
DB_NAME="库名"  # 替换为你的数据库名
DB_USER="用户名"  # 替换为你的数据库用户
DB_PASS="密码"  # 替换为你的数据库密码

export MYSQL_PWD="$DB_PASS"
mysqldump -u "$DB_USER" "$DB_NAME" > "$DB_BACKUP_FILE"
unset MYSQL_PWD

# 删除多余的 WordPress 备份，保留最近三次
find "$DEST_DIR" -maxdepth 1 -name "blog_backup_*.tar.gz" -printf '%T@ %p\n' | sort -n | awk 'NR>3 {print $2}' | xargs rm -f

# 删除多余的数据库备份，保留最近三次
find "$DEST_DIR" -maxdepth 1 -name "db_backup_*.sql" -printf '%T@ %p\n' | sort -n | awk 'NR>3 {print $2}' | xargs rm -f

# 输出备份文件路径
echo " "
echo " WordPress 备份完成: ${BLOG_BACKUP_FILE}"
echo " "
echo "------------------------------------------------------------------------"
echo " "
echo " MySQL 备份完成: ${DB_BACKUP_FILE}"
echo " "
