# mysql 高可用服务设置 （源码编译）

基于 nginx 和 keepalived 服务，用户可以实现应用系统访问 多个 MySQL 服务，只识别一个 IP 地址的高可用模式。

## Linux 系统信息
Centos 7.4 64位系统版本

## 环境准备
首先安装 openssl、perl pcre 、 zlib 库和模块

* openssl 库
```
wget https://www.openssl.org/source/openssl-1.1.1-pre8.tar.gz
tar -zxvf openssl-1.1.1-pre8.tar.gz
cd openssl-1.1.1-pre8
./config && make -j 4 && make install
```

然后再设置一下软连接
```
ln -sf /usr/local/lib64/libssl.so.1.1 /lib64/libssl.so.1.1
ln -sf /usr/local/lib64/libcrypto.so.1.1 /lib64/libcrypto.so.1.1
```

* perl pcre 模块
```
wget https://ftp.pcre.org/pub/pcre/pcre-8.42.tar.gz
tar -zxvf pcre-8.42.tar.gz
cd pcre-8.42
./configure && make -j 4 && make install
```

* zlib 库
```
wget http://www.zlib.net/fossils/zlib-1.2.11.tar.gz
tar -zxvf zlib-1.2.11.tar.gz
cd zlib-1.2.11
./configure && make -j 4 && make install
```

## 编译安装 Ngnix

* 编译 Nginx

```
wget http://nginx.org/download/nginx-1.15.7.tar.gz
tar -zxvf nginx-1.15.7.tar.gz
cd nginx-1.15.7
./configure \
--with-http_realip_module \
--with-http_addition_module \
--with-http_sub_module \
--with-http_dav_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_stub_status_module \
--with-http_auth_request_module \
--with-threads \
--with-stream_ssl_module \
--with-http_slice_module \
--with-file-aio \
--with-http_v2_module \
--with-http_ssl_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_stub_status_module \
--with-http_gzip_static_module \
--with-stream \
--with-pcre=/root/nginx_keepalived/nginx/pcre-8.42 \
--with-zlib=/root/nginx_keepalived/nginx/zlib-1.2.11 \
--with-openssl=/root/nginx_keepalived/nginx/openssl-1.1.1-pre8
make -j 4 && make install
```

> Note: 
> --with-pcre、--with-zlib和 --with-openssl 三个参数，需要填写刚才编译安装的完整地址，避免出现错误

* 配置 service 服务

新建一个脚本文件 /etc/init.d/nginx，内容如下

```
#! /bin/bash
# chkconfig: - 85 15
PATH=/usr/local/nginx
DESC="nginx daemon"
NAME=nginx
DAEMON=$PATH/sbin/$NAME
CONFIGFILE=$PATH/conf/$NAME.conf
PIDFILE=$PATH/logs/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME
set -e
[ -x "$DAEMON" ] || exit 0
do_start() {
  $DAEMON -c $CONFIGFILE || echo -n "nginx already running"
}
do_stop() {
  $DAEMON -s stop || echo -n "nginx not running"
}
do_reload() {
  $DAEMON -s reload || echo -n "nginx can't reload"
}
case "$1" in
start)
  echo -n "Starting $DESC: $NAME"
  do_start
  echo "."
  ;;
stop)
  echo -n "Stopping $DESC: $NAME"
  do_stop
  echo "."
  ;;
reload | graceful)
  echo -n "Reloading $DESC configuration..."
  do_reload
  echo "."
  ;;
restart)
  echo -n "Restarting $DESC: $NAME"
  do_stop
  do_start
  echo "."
  ;;
*)
  echo "Usage: $SCRIPTNAME {start|stop|reload|restart}" >&2
  exit 3
  ;;
esac
exit 0
```

* 为系统增加 Nginx 的 service 服务

添加执行权限
```
chmod a+x /etc/init.d/nginx
```

增加 nginx 服务
```
chkconfig --add nginx
```

如果要设置开机自启动，则执行以下命令
```
chkconfig nginx on
```

* 为 Nginx 配置 MySQL 的负载均衡

在 Nginx 配置文件 -- /usr/local/nginx/conf/nginx.conf 末尾增加以下内容
```
stream {
   upstream cloudsocket {
      hash $remote_addr consistent;
      server 192.168.10.211:3309 weight=5 max_fails=3 fail_timeout=30s;
      server 192.168.10.212:3309 weight=5 max_fails=3 fail_timeout=30s;
      server 192.168.10.213:3309 weight=5 max_fails=3 fail_timeout=30s;
   }
   server {
      listen 3308;#数据库服务器监听端口
      proxy_connect_timeout 10s;
      proxy_timeout 300s;#设置客户端和代理服务之间的超时时间，如果5分钟内没操作将自动断开。
      proxy_pass cloudsocket;
   }
}
```

> Note:
> Nginx 配置文件中的重要参数说明
```
* hash $remote_addr consistent，代表是对连接过来的IP 做Hash 路由，不同的机器请求Hash 到不同的机器，可以实现相同机器发送过来的请求，全部被分配到相同的MySQL 中去
* 如果不希望使用Hash 分配请求，可以直接将该行配置删除
* 多个 server 配置，代表该Nginx 需要负载均衡的MySQL 服务
* server 中配置的端口，为 MySQL 对外提供的端口
* listen 3308，代表 Nginx 启动了一个 3308 的端口
```

* 启动、停止、重启和重新加载 Nginx 服务和配置文件的命令

启动 nginx
```
systemctl start nginx.service
```

停止nginx服务
```
systemctl stop nginx.service
```

重启nginx服务
```
systemctl restart nginx.service
```

重新读取nginx配置(这个最常用, 不用停止nginx服务就能使修改的配置生效)
```
systemctl reload nginx.service
```

## 编译安装 Keepalived

* 编译安装

```
wget https://www.keepalived.org/software/keepalived-2.0.20.tar.gz
tar -zxvf keepalived-2.0.20.tar.gz
cd keepalived-2.0.20/
export LIBRARY_PATH=/usr/local/lib64
./configure
make -j 4 && make install
```

在编译 Keepalived 时，如果没有正确配置 openssl 的so 动态库，可能会出现如下错误信息遇到以下编译错误
```
keepalived-2.0.20/keepalived/check/check_ssl.c:81：对‘OPENSSL_init_ssl’未定义的引用
check/libcheck.a(check_ssl.o)：在函数‘init_ssl_ctx’中：
check_ssl.c:(.text+0x284)：对‘OPENSSL_init_ssl’未定义的引用
check_ssl.c:(.text+0x29a)：对‘TLS_method’未定义的引用
collect2: 错误：ld 返回 1
make[2]: *** [keepalived] 错误 1
make[2]: 离开目录“/root/nginx_keepalived/keepalived-2.0.20/keepalived”
make[1]: *** [all-recursive] 错误 1
make[1]: 离开目录“/root/nginx_keepalived/keepalived-2.0.20/keepalived”
make: *** [all-recursive] 错误 1
```

此时，只要找到 openssl 的so 安装目录，一般就是 /usr/local/lib64，然后执行以下命令，就可以解决
```
export LIBRARY_PATH=/usr/local/lib64
```

* 为系统增加 Keepalived 服务

```
cp keepalived/etc/init.d/keepalived /etc/init.d/
chmod a+x /etc/init.d/keepalived
chkconfig --add keepalived
```

* 设置 Keepalived 开启自启动
```
chkconfig keepalived on
```

* 设置 Keepalived 的启动参数

打开 /usr/local/etc/sysconfig/keepalived 文件，修改里面的内容
```
KEEPALIVED_OPTIONS="-D -f /usr/local/etc/keepalived/keepalived.conf"
```
 

* 为 Keepalived 增加一个 Nginx 的检测脚本
检测脚本路径 /usr/local/etc/keepalived/nginx_check.sh

```
#!/bin/bash
set -x

A=$(ps -C nginx --no-header | wc -l)
if [ $A -eq 0 ]; then

  echo $(date)':  nginx is not healthy, try to killall keepalived' >> /usr/local/etc/keepalived/keepalived.log
  killall keepalived
fi
```

* 设置 Keepalived 的服务

打开 /usr/local/etc/keepalived/keepalived.conf 文件

设置Keepalived 的Master 服务器

```
! Configuration File for keepalived
 
global_defs {
   router_id lvs-01
}
 
vrrp_script chk_nginx { 
    script "/usr/local/etc/keepalived/nginx_check.sh" 
    interval 3 
    weight -20 
}
 
vrrp_instance VI_1 {
    state MASTER
    interface eth1
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    ## 将 track_script 块加入 instance 配置块 
    track_script {
        chk_nginx  ## 执行 Nginx 监控的服务
    }
    virtual_ipaddress {
      10.211.55.23
    }
}
```
 

设置Keepalived 的Slave 服务器

```
! Configuration File for keepalived
 
global_defs {
   router_id lvs-02
}
 
vrrp_script chk_nginx { 
    script "/usr/local/etc/keepalived/nginx_check.sh" 
    interval 3 
    weight -20 
}
 
vrrp_instance VI_1 {
    state MASTER
    interface eth1
    virtual_router_id 51
    priority 90
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    ## 将 track_script 块加入 instance 配置块 
    track_script {
        chk_nginx  ## 执行 Nginx 监控的服务
    }
    virtual_ipaddress {
      10.211.55.23
    }
}
```

* Master 和 Slave 之间的差距
```
router_id  *** 设置的值不一样
priority   *** 权重不同， 主的权重更高
interface  *** 修改为当前机器的具体网卡名字
```

* 启动 keepalived 服务
```
systemctl start keepalived.service
```

* 停止 keepalived 服务
```
systemctl stop keepalived.service
```

* 查看 keepalived 设置的虚拟 IP 地址是否生效

可以通过以下命令查看
```
ip a
```
 
