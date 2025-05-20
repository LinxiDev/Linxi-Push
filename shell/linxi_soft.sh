#!/bin/bash
# Project: Linux 服务器软件一键安装脚本
# Author: 林夕
# Update: 2025-05-10
# Description: 
#   1.更新支持Ubuntu系列(修改软件依赖)
#   2.修复检测网络状态(无ping命令情况)
#   3.优化make编译(make -j$(nproc))
#   4.优化多版本Java共存环境变量切换支持(命令: linxi_soft.sh java 8/21/del)
#   5.新增NodeJS安装 V20.16.0

# 换源(国内)操作
switch_source(){
    bash <(curl -sSL https://linuxmirrors.cn/main.sh)
}

# 账号密码配置
MYSQL_PASSWORD="linxi.123"
REDIS_PASSWORD="linxi.123"
MINIO_USER="linxi"
MINIO_PASSWORD="linxi.123"
# 软件下载路径
soft_path="linxi_soft"
root_path=$PWD
# 端口配置
PORT_MYSQL="3306"
PORT_REDIS="6379"
PORT_CONSOLE_MINIO="9000"
PORT_MINIO="9800"
PORT_QL="5700"
PORT_TOMCAT="8080"

# 软件远程下载地址
declare -A software_urls
software_urls["Docker"]="https://get.docker.com"
software_urls["Docker-Compose"]="https://github.moeyy.xyz/https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-`uname -s`-`uname -m`"
software_urls["Qinglong"]="qinglong:latest"
software_urls["Python3"]="https://mirrors.huaweicloud.com/python/3.9.9/Python-3.9.9.tar.xz"
software_urls["JAVA"]="https://repo.huaweicloud.com/java/jdk/8u202-b08/jdk-8u202-linux-x64.tar.gz"
software_urls["JAVA21"]="https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_linux-x64_bin.tar.gz"
software_urls["Tomcat"]="https://mirrors.huaweicloud.com/apache/tomcat/tomcat-8/v8.5.96/bin/apache-tomcat-8.5.96.tar.gz"
software_urls["MINIO"]="http://dl.minio.org.cn/server/minio/release/linux-amd64/minio"
software_urls["Nginx"]="https://mirrors.huaweicloud.com/nginx/nginx-1.27.4.tar.gz"
software_urls["Redis"]="https://mirrors.huaweicloud.com/redis/redis-7.4.2.tar.gz"
software_urls["MySQL5.7.38"]="https://mirrors.huaweicloud.com/mysql/Downloads/MySQL-5.7/mysql-5.7.38-linux-glibc2.12-x86_64.tar.gz"
software_urls["MySQL8.0.29"]="https://mirrors.huaweicloud.com/mysql/Downloads/MySQL-8.0/mysql-8.0.29-linux-glibc2.12-x86_64.tar.xz"
software_urls["LibreOffice"]="https://downloadarchive.documentfoundation.org/libreoffice/old/7.6.7.2/rpm/x86_64/LibreOffice_7.6.7.2_Linux_x86-64_rpm.tar.gz"
software_urls["NodeJs20"]="https://unofficial-builds.nodejs.org/download/release/v20.16.0/node-v20.16.0-linux-x64-glibc-217.tar.gz"


# https://downloadarchive.documentfoundation.org/libreoffice/old/7.6.7.2/deb/x86_64/LibreOffice_7.6.7.2_Linux_x86-64_deb.tar.gz

# 安装Docker-Compose
install_Docker-Compose(){
    local filename=$1
    if command -v docker-compose &> /dev/null; then
        echo "[安装结束] Docker-Compose 已安装."
        read -p "[提示信息] 是否继续安装(Y/N)?" choice
        case "$choice" in 
        y|Y|yes ) echo "[重新安装] 开始重新安装Docker-Compose"
                rm -rf /usr/local/bin/docker-compose
                check_ok "[删除文件] 删除Docker-Compose相关文件"
                install_Docker-Compose $filename
                ;;
        n|N|no ) echo "[检查安装] 检查Docker-Compose安装状态"
                docker-compose --version
                ;;
        * ) echo "无效的输入，请输入Y或N!"
        esac
    else
        cp $filename /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        docker-compose --version
        check_ok "[安装完成] Docker-Compose 安装完成."
    fi
}

# 安装Docker
install_Docker(){
    local url=$1
    if command -v docker &> /dev/null; then
        echo "[安装结束] Docker 已安装."
    else
        curl -fsSL $url | bash -s docker --mirror Aliyun
        check_ok "[执行脚本] 执行脚本完成"
        echo "[开机自启] 设置Docker开机自启"
        systemctl enable docker.service
        echo "[安装结束] Docker 安装完成."
        service docker start
        check_ok "[安装完成] 正在启动Docker"
        docker -v
    fi
}

# 安装青龙面板
install_Qinglong(){
    local version=$1
    if command -v docker &> /dev/null; then
        if find / -type d -name "ql" 2>/dev/null | grep -q "ql"; then
            echo "[安装结束] 青龙面板已安装,无需再次安装."
        else
            docker run --name qinglong -d -p $PORT_QL:$PORT_QL -v /opt/ql/data:/ql/data -e QlBaseUrl="/" -e QlPort="$PORT_QL" --hostname qinglong --restart unless-stopped whyour/$version
            check_ok "[安装结束] 青龙面板安装并启动"
            docker ps -f name=qinglong
            check_ok "[安装完成] 检查青龙面板容器状态"
        fi
    else
        echo "[安装结束] 检测到Docker未安装,请先安装Docker."
    fi
}

# 切换JAVA环境变量
check_JavaVerion(){
    local version=$1
    local cversion=$(grep '^# Java [0-9]\+ Environment Variables' /etc/profile | awk '{print $3}' | cut -d'-' -f1)
    if [ -z "$cversion" ]; then
        echo "[环境变量] 未检测到自动安装的Java版本!"
        read -p "[提示信息] 是否默认补充Java8环境变量(Y/N)?" choice
        case "$choice" in 
            y|Y|yes ) 
                echo "[环境变量] 开始补充Java8环境变量"
                cversion=$(java -version 2>&1 | grep 'version' | awk -F '"' '{print $2}')
                ;;
            n|N|no ) 
                echo "[环境变量] 未安装Java8环境变量,请手动补充!"
                exit 1
                ;;
            * ) 
                echo "无效的输入，请输入Y或N!"
                exit 1
                ;;
        esac  # 确保 case 语句块被正确结束
    fi  # 结束 if 语句
    if [ "$version" == "del" ]; then
        echo "[环境变量] 正在清除Java环境变量!"
        sed -i "/# Java ${cversion} Environment Variables/,/^export PATH=\${JAVA_HOME}\\/bin:\$PATH/d" /etc/profile
        check_ok "[环境变量] 清除Java环境变量完成"
    elif [ "$version" == "$cversion" ]; then
        echo "[环境变量] Java 环境变量(${version})已经存在(一致)!"
    else
        echo "[环境变量] Java 环境变量(${cversion})与当前版本(${version})不一致,开始同步!"
        sed -i "/# Java ${cversion} Environment Variables/,/^export PATH=\${JAVA_HOME}\\/bin:\$PATH/d" /etc/profile
        if [ "$version" == "21" ]; then
            cat >> /etc/profile <<'EOF'
# Java 21 Environment Variables
export JAVA_HOME=/usr/local/java21
export JRE_HOME=${JAVA_HOME}
export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib  
export PATH=${JAVA_HOME}/bin:$PATH
EOF
        else
            if [ "$version" != "8" ]; then
                echo "[环境变量] 不支持的Java版本,默认使用Java8!"
            fi
            cat >> /etc/profile <<'EOF'
# Java 8 Environment Variables
export JAVA_HOME=/usr/local/java8
export JRE_HOME=${JAVA_HOME}/jre  
export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib  
export PATH=${JAVA_HOME}/bin:$PATH
EOF
        fi
        source /etc/profile
        check_ok "[环境变量] Java 环境变量同步成功,执行source /etc/profile或者重新连接即可生效!"
    fi
}

# 安装JAVA1.8
install_JAVA(){
    local filename=$1
    if [ -d "/usr/local/java8" ]; then
        echo "[安装结束] Java8已经安装!"
    else
        mkdir -p java8 && tar -zxvf "$filename" -C java8 --strip-components=1
        sudo mv java8 /usr/local/java8
        check_JavaVerion "8"
        java -version
        check_ok "[安装完成] 检查Java8安装状态"
        echo "[完成提示] 尝试输出 echo \$JAVA_HOME如果显示为空则执行source /etc/profile或者重新连接即可!"
        source /etc/profile
    fi
}



# 安装JAVA 21
install_JAVA21(){
    local filename=$1
    if [ -d "/usr/local/java21" ]; then
        echo "[安装结束] Java21已经安装!"
    else
        mkdir -p java21 && tar -zxvf "$filename" -C java21 --strip-components=1
        sudo mv java21 /usr/local/java21
        check_JavaVerion "21"
        java -version
        check_ok "[安装完成] 检查Java21安装状态"
        echo "[完成提示] 尝试输出 echo \$JAVA_HOME如果显示为空则执行source /etc/profile或者重新连接即可!"
        source /etc/profile
    fi
}

# 安装Minio
install_MINIO(){
    local filename=$1
    if [ -d "/usr/local/minio" ]; then
        echo "[安装结束] Minio已经安装!"
        echo "[启动服务] 服务Minio开始启动!"
        sudo systemctl restart minio
        check_ok "[启动服务] 服务Minio开始成功 默认端口:$PORT_CONSOLE_MINIO 、$PORT_MINIO 路径:/usr/local/minio 账号:$MINIO_USER 密码:$MINIO_PASSWORD !"
        echo "[提示信息] 密码可到/usr/local/minio/minio.conf 修改PASSWORD后的参数! systemctl stop minio关闭服务"
    else
        mkdir /usr/local/minio
        mkdir /usr/local/minio/data
        mv minio /usr/local/minio
        chmod +x /usr/local/minio/minio
        echo "MINIO_VOLUMES=\"/usr/local/minio/data\"
MINIO_OPTS=\"--console-address :$PORT_CONSOLE_MINIO --address :$PORT_MINIO\"
MINIO_ROOT_USER=\"$MINIO_USER\"
MINIO_ROOT_PASSWORD=\"$MINIO_PASSWORD\"" | sudo tee /usr/local/minio/minio.conf
        echo "[配置软件] 开始配置Minio!"
        cat > /tmp/soft.service <<EOF
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target
#minio文件具体位置
AssertFileIsExecutable=/usr/local/minio/minio
[Service]
# User and group 用户 组
User=root
Group=root
#创建的配置文件 minio.conf
EnvironmentFile=/usr/local/minio/minio.conf
ExecStart=/usr/local/minio/minio server \$MINIO_OPTS \$MINIO_VOLUMES
# Let systemd restart this service always
Restart=always
# Specifies the maximum file descriptor number that can be opened by this process
LimitNOFILE=65536
# Disable timeout logic and wait until process is stopped
TimeoutStopSec=infinity
SendSIGKILL=no
[Install]
WantedBy=multi-user.target
EOF
        sudo /bin/mv /tmp/soft.service /lib/systemd/system/minio.service
        check_ok "[安装服务] 服务Minio安装"
        echo "[加载服务] 服务Minio开始加载!"
        sudo systemctl daemon-reload
        sudo systemctl enable minio
        echo "[启动服务] 服务Minio开始启动!"
        sudo systemctl start minio
        check_ok "[启动服务] 服务Minio开始成功 默认端口:$PORT_CONSOLE_MINIO 、$PORT_MINIO 路径:/usr/local/minio 账号:$MINIO_USER 密码:$MINIO_PASSWORD !"
        echo "[提示信息] 密码可到/usr/local/minio/minio.conf 修改PASSWORD后的参数! systemctl stop minio关闭服务"
    fi
}

# 安装Tomcat
install_Tomcat(){
    local filename=$1
    if command -v java &> /dev/null; then
        echo "[安装结束] JAVA 已安装,开始Tomcat8安装."
        if [ -d "/usr/local/tomcat8" ]; then
            echo "[安装结束] Tomcat8已经安装!"
            echo "[启动程序] 开启Tomcat服务,$PORT_TOMCAT 端口!"
            source /etc/profile
            /usr/local/tomcat8/bin/shutdown.sh
            /usr/local/tomcat8/bin/startup.sh
            echo "[安装完成] $PORT_TOMCAT 端口检查Tomcat是否正确安装,无法访问请关闭防火墙service firewalld stop!"
            echo "[相关命令] tomcatdown.sh 关闭服务 tomcatup.sh 开启服务 或执行:/usr/local/tomcat8/bin/shutdown.sh(startup.sh) "
        else
            tar -zxvf "$filename"
            filename=$(basename "$filename") # 获取不包含路径和后缀的文件名
            filename="${filename%.*.*}" # 去除尾部的 .tar.gz 或 .tar.xz
            sudo mv $filename /usr/local/tomcat8
            echo "[启动程序] 开启Tomcat服务,$PORT_TOMCAT 端口!"
            source /etc/profile
            sed -i.bak "s/8080/${PORT_TOMCAT}/" /usr/local/tomcat8/conf/server.xml
            /usr/local/tomcat8/bin/startup.sh
            # 检查Tomcat是否安装
            if [ -f "/usr/bin/tomcatup.sh" ]; then
                # Tomcat已安装，替换软链接
                sudo rm /usr/bin/tomcatup.sh     # 删除旧的软链接
                sudo rm /usr/bin/tomcatdown.sh     # 删除旧的软链接
                sudo ln -s /usr/local/tomcat8/bin/shutdown.sh /usr/bin/tomcatdown.sh   # 创建新的软链接，将xxx替换为实际版本号
                sudo ln -s /usr/local/tomcat8/bin/startup.sh /usr/bin/tomcatup.sh   # 创建新的软链接，将xxx替换为实际版本号
                echo "[软链接] Tomcat软链接已更新"
            else
                # Tomcat未安装，创建软链接
                sudo ln -s /usr/local/tomcat8/bin/shutdown.sh /usr/bin/tomcatdown.sh   # 创建新的软链接，将xxx替换为实际版本号
                sudo ln -s /usr/local/tomcat8/bin/startup.sh /usr/bin/tomcatup.sh   # 创建新的软链接，将xxx替换为实际版本号
                echo "[软链接] Tomcat软链接已创建"
            fi
            echo "[安装完成] $PORT_TOMCAT 端口检查Tomcat是否正确安装,无法访问请关闭防火墙service firewalld stop!"
            echo "[相关指令] tomcatdown.sh 关闭服务 tomcatup.sh 开启服务 或执行:/usr/local/tomcat8/bin/shutdown.sh(startup.sh) "
        fi
    else
        echo "[安装结束] 检测到JAVA未安装,请先安装JAVA."
    fi
}

# 安装Nginx
install_Nginx(){
    local filename=$1
    if [ -d "/usr/local/nginx" ]; then
        echo "[安装结束] Nginx已经安装!"
        echo "[启动服务] 服务Nginx开始启动!"
        sudo systemctl restart nginx
        check_ok "[启动服务] 服务Nginx开始成功 默认端口:80 路径:/usr/local/nginx !"
    else
        tar -zxvf "$filename"
        filename=$(basename "$filename") # 获取不包含路径和后缀的文件名
        filename="${filename%.*.*}" # 去除尾部的 .tar.gz 或 .tar.xz
        cd $filename
        echo "[编译程序] 开始编译Nginx!"
        sudo ./configure --prefix=/usr/local/nginx --with-http_ssl_module --with-stream --with-stream_ssl_module --with-stream_ssl_preread_module
        sudo make -j$(nproc) && sudo make install
        check_ok "[编译完成] 编译Nginx"
        echo "[配置软件] 开始配置Nginx!"
        cat > /tmp/soft.service <<EOF
[Unit]
Description=Nginx HTTP Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/usr/local/nginx/sbin/nginx -s stop
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
        sudo /bin/mv /tmp/soft.service /lib/systemd/system/nginx.service
        check_ok "[安装服务] 服务Nginx安装"
        echo "[加载服务] 服务Nginx开始加载!"
        sudo systemctl daemon-reload
        sudo systemctl enable nginx
        echo "[启动服务] 服务Nginx开始启动!"
        sudo systemctl start nginx
        check_ok "[启动服务] 服务Nginx开始成功 默认端口:80 路径:/usr/local/nginx !"
        # 检查Nginx是否安装
        if [ -f "/usr/bin/nginx" ]; then
            # Nginx已安装，替换软链接
            sudo rm /usr/bin/nginx     # 删除旧的软链接
            sudo ln -s /usr/local/nginx/sbin/nginx /usr/bin/nginx   # 创建新的软链接，将xxx替换为实际版本号
            echo "[软链接] Nginx软链接已更新"
        else
            # Nginx未安装，创建软链接
            sudo ln -s /usr/local/nginx/sbin/nginx /usr/bin/nginx   # 创建软链接，将xxx替换为实际版本号
            echo "[软链接] Nginx软链接已创建"
        fi
    fi
}

# 安装Redis
install_Redis(){
    local filename=$1
    if [ -d "/usr/local/redis" ]; then
        echo "[安装结束] Redis6已经安装!"
        echo "[启动服务] 服务Redis6开始启动!"
        sudo systemctl restart redis
        check_ok "[启动服务] 服务Redis6开始成功 端口:$PORT_REDIS 密码:$REDIS_PASSWORD!"
        echo "[提示信息] 密码可到/usr/local/redis/redis.conf 修改requirepass后的参数! systemctl stop redis关闭服务"
    else
        tar -zxvf "$filename"
        filename=$(basename "$filename") # 获取不包含路径和后缀的文件名
        filename="${filename%.*.*}" # 去除尾部的 .tar.gz 或 .tar.xz
        cd $filename
        echo "[编译程序] 开始编译Redis6!"
        sudo make -j$(nproc) && sudo make PREFIX=/usr/local/redis install
        check_ok "[编译完成] 编译Redis6"
        sudo mv redis.conf /usr/local/redis/redis.conf
        # 修改bind地址为0.0.0.0，守护进程设置为yes，设置密码为linxi110
        sed -i 's/^bind 127.0.0.1 -::1$/bind 0.0.0.0 -::1/' /usr/local/redis/redis.conf
        sed -i 's/^daemonize no$/daemonize yes/' /usr/local/redis/redis.conf
        sed -i "s/^port [0-9]\+/port $PORT_REDIS/" /usr/local/redis/redis.conf
        sed -i "s/^# requirepass foobared$/requirepass $REDIS_PASSWORD/" /usr/local/redis/redis.conf
        cat > /tmp/soft.service <<EOF
[Unit]
Description=redis-server
After=network.target
 
[Service]
Type=forking
ExecStart=/usr/local/redis/bin/redis-server /usr/local/redis/redis.conf
PrivateTmp=true
 
[Install]
WantedBy=multi-user.target
EOF
        echo "[安装服务] 安装Redis6服务,$PORT_REDIS 端口!"
        sudo /bin/mv /tmp/soft.service /lib/systemd/system/redis.service
        check_ok "[安装服务] 服务Redis6安装"
        echo "[加载服务] 服务Redis6开始加载!"
        sudo systemctl daemon-reload
        sudo systemctl enable redis
        echo "[启动服务] 服务Redis6开始启动!"
        sudo systemctl start redis
        check_ok "[启动服务] 服务Redis6开始成功 端口:$PORT_REDIS 密码:$REDIS_PASSWORD!"
        # 检查Redis是否安装
        if [ -f "/usr/bin/redis-cli" ]; then
            # Redis已安装，替换软链接
            sudo rm /usr/bin/redis-cli     # 删除旧的软链接
            sudo ln -s /usr/local/redis/bin/redis-cli /usr/bin/redis-cli   # 创建新的软链接，将xxx替换为实际版本号
            echo "[软链接] Redis软链接已更新"
        else
            # Redis未安装，创建软链接
            sudo ln -s /usr/local/redis/bin/redis-cli /usr/bin/redis-cli   # 创建软链接，将xxx替换为实际版本号
            echo "[软链接] Redis软链接已创建"
        fi
        echo "[安装完成] $PORT_REDIS 端口检查Redis6是否正确安装,无法访问请关闭防火墙service firewalld stop!"
        echo "[提示信息] 密码可到/usr/local/redis/redis.conf 修改requirepass后的参数! systemctl stop redis关闭服务 redis-cli命令行访问!"
        
    fi
}

# 安装Python3
install_Python3(){
    local filename=$1
    if [ -d "/usr/local/Python3" ]; then
        echo "[安装结束] Python3已经安装!"
        echo "[检查软件] 检查软件是否安装成功!"
        python3 -V
    else
        tar -xvJf "$filename"
        filename=$(basename "$filename") # 获取不包含路径和后缀的文件名
        filename="${filename%.*.*}" # 去除尾部的 .tar.gz 或 .tar.xz
        cd $filename
        echo "[安装依赖] 开始安装Python3依赖!"
        if [ -x "$(command -v apt)" ]; then
            apt install -y libbz2-dev libffi-dev
        fi
        if [ -x "$(command -v yum)" ]; then
            yum install -y bzip2-devel libffi-devel
        fi
        check_ok "[安装依赖] 安装Python3依赖"
        echo "[编译程序] 开始编译Python3!"
        # 获取gcc的版本信息
        gcc_version=$(gcc -dumpversion)
        # 比较版本大小
        if [[ "$(printf '%s\n' "$gcc_version" "8.1.0" | sort -V | head -n1)" == "8.1.0" ]]; then
            echo "[gcc版本] GCC满足最低要求(8.1.0)"
            ./configure --prefix=/usr/local/Python3 --enable-optimizations
        else
            echo "[gcc版本] GCC版本小于8.1.0"
            ./configure --prefix=/usr/local/Python3
        fi
        sudo make -j$(nproc) && sudo make install
        check_ok "[编译完成] 编译Python3"
        echo "[环境变量] 配置Python3的环境变量!"
        cat >> /etc/profile <<'EOF'

# Python Environment Variables
export PATH=/usr/local/Python3/bin:$PATH
EOF
        source /etc/profile
        check_ok "[环境变量] 配置Python3的环境变量"
        echo "[配置国源] 配置pip全局国内源!"
        mkdir -p $HOME/.pip
        cat > $HOME/.pip/pip.conf <<EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
[install]
trusted-host=pypi.tuna.tsinghua.edu.cn
EOF
        check_ok "[配置国源] 配置pip全局国内源"
        echo "[检查软件] 检查软件是否安装成功!"
        python3 -V
        pip3 -V
        echo "[检查软件] 检查软件安装成功,无法执行命令:执行source /etc/profile或者重新连接即可!"
        source /etc/profile
    fi
}

# 安装Office开源的办公套件
install_LibreOffice(){
    local filename=$1
    if [ -d "/usr/bin/libreoffice" ]; then
        echo "[安装结束] LibreOffice已经安装!"
    else
        tar -zxvf "$filename"
        filename=$(basename "$filename") # 获取不包含路径和后缀的文件名
        # filename="${filename%.*.*}" # 去除尾部的 .tar.gz 或 .tar.xz (对应解压后的文件夹名)
        if [ -x "$(command -v yum)" ]; then
            filename="LibreOffice_7.6.7.2_Linux_x86-64_rpm"
            echo "[安装依赖] libreoffice-headless开始安装!"
            yum install -y libreoffice-headless
            sudo yum install ./$filename/RPMS/*.rpm -y
        fi
        if [ -x "$(command -v apt)" ]; then
            filename="LibreOffice_7.6.7.2_Linux_x86-64_deb"
            # echo "[安装依赖] libreoffice-headless开始安装!"
            # sudo apt install -y libreoffice-headless
            sudo dpkg -i ./$filename/DEBS/*.deb
            sudo apt-get install -f
        fi
        # check_ok "[安装依赖] libreoffice-headless安装"
        echo "[创建软连接] 开始创建 libreoffice 软连接!"
        sudo rm /usr/bin/libreoffice     # 删除旧的软链接
        sudo ln -s /usr/local/bin/libreoffice7.6 /usr/bin/libreoffice   # 创建新的软链接，将xxx替换为实际版本号
        check_ok "[创建软连接] 创建 libreoffice 软连接"
        echo "[检查软件] 检查软件是否安装成功!"
        libreoffice --version
        echo "[操作提示] libreoffice --version / libreoffice7.6 --version"
    fi
}

# 安装MySQL 统一处理
install_MySQL(){
    local filename=$1
    local version=$2
    sudo mv $filename /usr/local/mysql
    if id mysql &>/dev/null; then
        echo "[创建用户] 已存在mysql用户,跳过!"
    else
        echo "[创建用户] 开始创建mysql用户!"
        groupadd mysql
        sudo useradd -r -g mysql mysql
        mkdir -p /usr/local/mysql/Data
        chown -R mysql:mysql /usr/local/mysql/Data
        chown -R mysql:mysql /usr/local/mysql
    fi
    echo "[配置软件] 开始配置MySQL!"
    cat > /usr/local/mysql/my.cnf << EOF
[mysqld]
bind-address=0.0.0.0
port=${PORT_MYSQL}
user=mysql
basedir=/usr/local/mysql
datadir=/usr/local/mysql/Data/
socket=/tmp/mysql.sock
log-error=/usr/local/mysql/Data/mysql.err
pid-file=/usr/local/mysql/Data/mysql.pid
#character config
character_set_server=utf8mb4
symbolic-links=0
explicit_defaults_for_timestamp=true
EOF
    echo "[初始化MySQL] 开始初始化MySQL数据库!"
    sudo /usr/local/mysql/bin/mysqld --defaults-file=/usr/local/mysql/my.cnf --console --basedir=/usr/local/mysql --datadir=/usr/local/mysql/Data/ --user=mysql --initialize
    file_contents=$(cat /usr/local/mysql/Data/mysql.err)
    # 使用正则表达式提取密码内容
    password=$(echo "$file_contents" | grep -o 'A temporary password is generated for root@localhost: .*' | awk -F ': ' '{print $2}')
    # 输出密码内容
    echo "MySQL Successfully Password: $password"
    check_ok "[初始化MySQL] 初始化MySQL数据库"
    cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysql
    echo "[启动服务] 服务MySQL开始启动!"
    if [ -d "/var/log/mariadb" ]; then
        echo "[路径配置] mariadb文件夹已存在跳过!"
    else
        echo "[路径配置] mariadb文件夹不存在,创建!"
        mkdir /var/log/mariadb
        touch /var/log/mariadb/mariadb.log
        check_ok "[路径配置] mariadb文件夹创建成功!"
    fi
    chown -R mysql:mysql /var/log/mariadb/
    service mysql start
    check_ok "[启动服务] 服务MySQL启动"
    # 检查MySQL是否安装
    if [ -f "/usr/bin/mysql" ]; then
        # MySQL已安装，替换软链接
        sudo rm /usr/bin/mysql     # 删除旧的软链接
        sudo ln -s /usr/local/mysql/bin/mysql /usr/bin/mysql   # 创建新的软链接，将xxx替换为实际版本号
        echo "[软链接] MySQL软链接已更新"
    else
        # MySQL未安装，创建软链接
        sudo ln -s /usr/local/mysql/bin/mysql /usr/bin/mysql   # 创建软链接，将xxx替换为实际版本号
        echo "[软链接] MySQL软链接已创建"
    fi
    echo "[修改配置] 服务MySQL配置修改!"
    /usr/local/mysql/bin/mysql -uroot -p${password} -hlocalhost -e "ALTER USER USER() IDENTIFIED BY '${MYSQL_PASSWORD}';CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;ALTER USER 'root'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';flush privileges;" --connect-expired-password
    check_ok "[修改配置] 服务MySQL配置修改"
    echo "[防火墙] 自动关闭防火墙!"
    # 检测系统类型并执行相应的命令
    if [ -x "$(command -v firewall-cmd)" ]; then
        # CentOS / RHEL 7+
        systemctl stop firewalld
        systemctl disable firewalld
    elif [ -x "$(command -v ufw)" ]; then
        # Ubuntu / Debian
        ufw disable
    else
        echo "不支持的防火墙管理工具或未检测到防火墙服务,请手动设置关闭防火墙"
    fi
    service mysql restart
    echo "[安装完成] MySQL$version Root密码:[${MYSQL_PASSWORD}] 端口:$PORT_MYSQL 默认开启远程访问!"
}

# 安装MySQL5.7
install_MySQL5.7.38(){
    local filename=$1
    if [ -d "/usr/local/mysql" ]; then
        mysql_version=$(mysql -V | sed -e 's/^mysql //' -e 's/, for.*//')
        echo "[安装结束] MySQL已经安装,版本号: $mysql_version!"
        read -p "[提示信息] 是否继续安装(Y/N)?" choice
        case "$choice" in 
        y|Y|yes ) echo "[重新安装] 开始重新安装MySQL"
                service mysql stop
                check_ok "[停止服务] 停止MySQL服务"
                rm -rf /usr/local/mysql
                rm -rf /usr/bin/mysql
                check_ok "[删除文件] 删除MySQL相关文件"
                tar -zxvf "$filename"
                filename=$(basename "$filename") # 获取不包含路径和后缀的文件名
                filename="${filename%.*.*}" # 去除尾部的 .tar.gz 或 .tar.xz
                install_MySQL $filename "5.7.38"
                ;;
        n|N|no ) echo "[启动服务] 服务MySQL开始启动,端口:$PORT_MYSQL 密码:$MYSQL_PASSWORD!"
                service mysql restart
                check_ok "[启动服务] 服务MySQL启动"
                ;;
        * ) echo "无效的输入，请输入Y或N!"
        esac
    else
        tar -zxvf "$filename"
        filename=$(basename "$filename") # 获取不包含路径和后缀的文件名
        filename="${filename%.*.*}" # 去除尾部的 .tar.gz 或 .tar.xz
        install_MySQL $filename "5.7.38"
    fi
}

# 安装MySQL8.0
install_MySQL8.0.29(){
    local filename=$1
    if [ -d "/usr/local/mysql" ]; then
        mysql_version=$(mysql -V | sed -e 's/^mysql //' -e 's/, for.*//')
        echo "[安装结束] MySQL已经安装,版本号: $mysql_version!"
        read -p "[提示信息] 是否继续安装(Y/N)?" choice
        case "$choice" in 
        y|Y|yes ) echo "[重新安装] 开始重新安装MySQL"
                service mysql stop
                check_ok "[停止服务] 停止MySQL服务"
                rm -rf /usr/local/mysql
                rm -rf /usr/bin/mysql
                check_ok "[删除文件] 删除MySQL相关文件"
                tar -xvf "$filename"
                filename=$(basename "$filename") # 获取不包含路径和后缀的文件名
                filename="${filename%.*.*}" # 去除尾部的 .tar.gz 或 .tar.xz
                install_MySQL $filename "8.0.29"
                ;;
        n|N|no ) echo "[启动服务] 服务MySQL开始启动,端口:$PORT_MYSQL 密码:$MYSQL_PASSWORD!"
                service mysql restart
                check_ok "[启动服务] 服务MySQL启动"
                ;;
        * ) echo "无效的输入，请输入Y或N!"
        esac
    else
        tar -xvf "$filename"
        filename=$(basename "$filename") # 获取不包含路径和后缀的文件名
        filename="${filename%.*.*}" # 去除尾部的 .tar.gz 或 .tar.xz
        install_MySQL $filename "8.0.29"
    fi
}

# 安装NodeJS20
install_NodeJs20(){ 
    local filename=$1
    if [ -d "/usr/local/nodejs" ]; then
        echo "[安装结束] NodeJS V20 已经安装!"
        echo "[检查软件] 检查软件是否安装成功!"
        node -v && npm -v
    else
        tar -zxvf "$filename"
        filename=$(basename "$filename") # 获取不包含路径和后缀的文件名
        filename="${filename%.*.*}" # 去除尾部的 .tar.gz 或 .tar.xz
        sudo mv $filename /usr/local/nodejs
        # 配置环境变量
        echo "[环境变量] 配置NodeJS V20 的环境变量!"
        cat >> /etc/profile <<'EOF'

# NodeJS V20 Environment Variables
NODEJS_HOME=/usr/local/nodejs
export PATH=$NODEJS_HOME/bin:$PATH
EOF
        source /etc/profile
        check_ok "[环境变量] 配置NodeJS V20 的环境变量"
        echo "[配置国源] 配置npm全局国内源(阿里源)!"
        npm config set registry https://registry.npmmirror.com
        npm config set prefix "/usr/local/nodejs/node_global"
        npm config set cache "/usr/local/nodejs/node_cache"
        check_ok "[配置国源] 配置npm全局国内源(阿里源)"
        npm config get
        check_ok "[配置路径] 配置npm路径"
        echo "[检查软件] 检查软件是否安装成功!"
        node -v
        npm -v
        echo "[检查软件] 检查软件安装成功,无法执行命令:执行source /etc/profile或者重新连接即可!"
        source /etc/profile
        # # 检查NodeJS软连接是否安装
        # if [ -f "/usr/bin/node" ]; then
        #     # NodeJS已安装，替换软链接
        #     sudo rm /usr/bin/node
        #     sudo rm /usr/bin/npm
        #     sudo rm /usr/bin/npx
        #     sudo rm /usr/bin/corepack
        #     sudo ln -s /usr/local/nodejs/bin/node /usr/bin/node
        #     sudo ln -s /usr/local/nodejs/bin/npm /usr/bin/npm
        #     sudo ln -s /usr/local/nodejs/bin/npx /usr/bin/npx
        #     sudo ln -s /usr/local/nodejs/bin/corepack /usr/bin/corepack
        #     echo "[软链接] NodeJS V20 软链接已更新"
        # else
        #     # NodeJS未安装，创建软链接
        #     sudo ln -s /usr/local/nodejs/bin/node /usr/bin/node
        #     sudo ln -s /usr/local/nodejs/bin/npm /usr/bin/npm
        #     sudo ln -s /usr/local/nodejs/bin/npx /usr/bin/npx
        #     sudo ln -s /usr/local/nodejs/bin/corepack /usr/bin/corepack
        #     echo "[软链接] NodeJS V20 软链接已创建"
        # fi
    fi
}

# 运行状态处理
check_ok() {
    if [ $? -ne 0 ]; then
        echo "$1 错误:发生异常错误!!!"
        exit 1
    else
        echo "$1 成功:操作成功"
    fi
}

# 定义检查网络连接的函数
check_network() {
    # 检查系统中是否有ping命令
    if [ -x "$(command -v ping)" ]; then
        # 使用ping命令检测网络
        ping -c 1 bing.com > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "[网络检测] 网络连接正常 (通过ping)"
            return 0  # 返回0表示网络连接正常
        else
            echo "[网络检测] 无法连接到网络 (通过ping)"
            return 1  # 返回1表示无法连接到网络
        fi
    elif [ -x "$(command -v curl)" ]; then
        # 如果没有ping命令，尝试使用curl命令检测网络
        curl --silent --head http://bing.com > /dev/null
        if [ $? -eq 0 ]; then
            echo "[网络检测] 网络连接正常 (通过curl)"
            return 0  # 返回0表示网络连接正常
        else
            echo "[网络检测] 无法连接到网络 (通过curl)"
            return 1  # 返回1表示无法连接到网络
        fi
    else
        (echo > /dev/tcp/bing.com/80) > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "[网络检测] 网络连接正常 (通过tcp)"
            return 0  # 返回0表示网络连接正常
        else
            echo "[网络检测] 无法连接到网络 (通过tcp)"
            return 1  # 返回1表示无法连接到网络
        fi
    fi
}

# 检查文件是否存在
check_file_exists() {
    local file="$1"
    if [ -z "$file" ]; then
        echo "[文件检查] 文件名不能为空!"
        return 2
    elif [ -f "$file" ]; then
        echo "[文件检查] 文件 $file 已存在!"
        return 0
    else
        echo "[文件检查] 文件 $file 不存在!"
        return 1
    fi
}


# 检查文件夹是否存在
check_dir_exists() {
    local dir="$1"
    if [ -d "$dir" ]; then
        echo "[文件夹检查] 文件夹 $dir 已存在!"
        return 0
    else
        echo "[文件夹检查] 文件夹 $dir 不存在!"
        mkdir "$dir"
        check_ok "[文件夹检查] ${dir}创建"
        return 1
    fi
}

# 自动选择包管理软件并检查安装依赖
check_requirements() {
    if [ -x "$(command -v yum)" ]; then
        echo "[安装依赖] 开始安装基础依赖(RHEL/Rocky)!"
        for pkg in gcc tcl make wget curl pcre-devel zlib-devel openssl-devel libffi-devel sqlite-devel libaio; do
            if ! rpm -q $pkg > /dev/null 2>&1; then
                sudo yum install -y $pkg
                check_ok "[安装依赖] 安装依赖${pkg}"
            else
                echo "[安装依赖] 依赖${pkg}已经安装!"
            fi
        done
    fi
    if [ -x "$(command -v apt)" ]; then
        echo "[安装依赖] 开始安装基础依赖(Ubuntu/kali)!"
        for pkg in build-essential manpages-dev make wget curl libpcre++-dev libssl-dev zlib1g-dev libaio1 libnuma-dev libtinfo5 libncurses5; do
            if ! dpkg -l $pkg > /dev/null 2>&1; then
                sudo apt install -y $pkg
                check_ok "[安装依赖] 安装依赖${pkg}"
            else
                echo "[安装依赖] 依赖${pkg}已经安装!"
            fi
        done
    fi
}

# 获取系统信息
get_system_info() {
    # 获取发行版
    distribution=$(grep 'DISTRIB_ID' /etc/*release* | cut -d '=' -f2)
    # 获取版本号
    version=$(grep 'DISTRIB_RELEASE' /etc/*release* | cut -d '=' -f2)
    # 获取架构
    architecture=$(uname -m)
    # 判断发行版是否为空
    if [ -z "$distribution" ]; then
        # 获取发行版
        distribution=$(grep 'PRETTY_NAME' /etc/os-release | sed 's/PRETTY_NAME=//; s/"//g')
        # 获取版本号
        version=$(grep 'VERSION_ID' /etc/os-release | awk -F '=' '{print $2}' | sed 's/"//g')
        # 获取架构
        architecture=$(uname -m)
    fi
    # 输出结果
    echo "[系统信息] 发行版本: $distribution 版本号: $version 架构: $architecture"
}

# 下载软件安装包
download_soft() {
    local software=$1
    check_network
    # 检查网络
    if [ $? -eq 0 ]; then
        local url=${software_urls[$software]}
        # 下载逻辑
        if [ -x "$(command -v apt)" ]; then
            url=$(echo "$url" | sed 's/rpm/deb/g')
        fi
        local filename=$(basename "$url")
        # 检查 URL 是否以 "http://" 或 "https://" 开头
        if [[ $url =~ ^(https?://)(.*)$ ]]; then
            # 提取文件名
            if [[ ${BASH_REMATCH[2]} =~ /([^/]+)$ ]]; then
                filename="${BASH_REMATCH[1]}"
            else
                filename=""
            fi
        else
            filename=""
        fi
        echo "[检测软件] ${software}软件包"
        check_file_exists "$filename"
        local status=$?
        if [ $status -eq 2 ]; then
            filename=$url
        elif [ $status -ne 0 ]; then
            echo "[开始下载] ${software}软件包"
            sudo curl -O $url
            check_ok "[开始完成] ${software}软件包"
        fi
        echo "[开始安装] ${software}软件"
        # 安装函数
        install_$software "$filename"
    else
        # 如果无法连接到网络，则检测当前文件夹
        echo "无法连接到网络，检测当前文件夹..."
        install_$software "$filename"
fi
}

# 主函数-菜单
main() {
    echo "
██╗     ██╗███╗   ██╗██╗  ██╗██╗      ███████╗ ██████╗ ███████╗████████╗
██║     ██║████╗  ██║╚██╗██╔╝██║      ██╔════╝██╔═══██╗██╔════╝╚══██╔══╝
██║     ██║██╔██╗ ██║ ╚███╔╝ ██║█████╗███████╗██║   ██║█████╗     ██║   
██║     ██║██║╚██╗██║ ██╔██╗ ██║╚════╝╚════██║██║   ██║██╔══╝     ██║   
███████╗██║██║ ╚████║██╔╝ ██╗██║      ███████║╚██████╔╝██║        ██║   
╚══════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝      ╚══════╝ ╚═════╝ ╚═╝        ╚═╝   
        项目:一键安装脚本          BY-林夕          版本:V1.2.2
        提示指令:
            快速换源(国内): <soft文件名.sh> source
            快速切换JAVA: <soft文件名.sh> java 8 | 21
            关闭防火墙: service firewalld stop | sudo ufw disable
            安装Docker(快速): bash <(curl -sSL https://linuxmirrors.cn/docker.sh)
        注意: 使用脚本前,请务必在首次使用时修改默认内置账号/密码,避免面临潜在的安全风险!
"
    # 调用函数并获取返回值
    get_system_info
    software=()
    for key in "${!software_urls[@]}"; do
        software+=($key)
    done
    echo "支持安装的软件列表：(键入0退出)"
    for index in "${!software[@]}"
    do
        ((display_index = index + 1))
        if [ $display_index -lt 10 ]; then
            display_index="0$display_index"
        fi
        echo "$display_index. ${software[index]}"
    done
    read -p "请输入软件对应的数值（多个以空格分隔）：" input
    if [ "$input" = "0" ]; then
        echo "[退出程序] 用户选择退出，程序结束。"
        exit 0
    fi
    if [ -d "$soft_path" ]; then
        echo "[软件路径] ${soft_path}文件夹已存在！"
        cd "$soft_path"
    else
        echo "[软件路径] ${soft_path}文件夹不存在。正在创建文件夹..."
        mkdir "$soft_path"
        check_ok "[软件路径] ${soft_path}创建"
        cd "$soft_path"
    fi
    check_requirements
    indices=($input)
    for index in "${indices[@]}"
    do
        cd $root_path/$soft_path
        if ((index >= 0 && index <= ${#software[@]})); then
            soft="${software[index-1]}"
            echo "[开始安装] 第${index-1}个软件: $soft"
            download_soft "$soft"
        else
            echo "[开始安装] 第${index-1}个软件: 不存在该软件"
        fi
        ((index++))
    done
}

# 脚本入口
if [ "$1" == "source" ]; then
    switch_source
elif [ "$1" == "java" ]; then
    check_JavaVerion "$2"
else
    main
fi
