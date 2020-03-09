#!/bin/bash

bin=`which $0`
bin=`dirname ${bin}`
basedir=`cd "$bin"; pwd`

cd nginx
echo "begin to install openssl"
tar -zxf openssl-1.1.1-pre8.tar.gz
cd openssl-1.1.1-pre8
./config > /dev/null && make -j 4 > /dev/null && make install > /dev/null

ln -sf /usr/local/lib64/libssl.so.1.1 /lib64/libssl.so.1.1
ln -sf /usr/local/lib64/libcrypto.so.1.1 /lib64/libcrypto.so.1.1

cd ..

echo "install openssl over"

echo "begin to install pcre"
tar -zxf pcre-8.42.tar.gz
cd pcre-8.42
./configure > /dev/null && make -j 4 > /dev/null && make install > /dev/null

echo "install pcre over"

cd ..

echo "begin to install zlib"

tar -zxf zlib-1.2.11.tar.gz
cd zlib-1.2.11
./configure > /dev/null && make -j 4 > /dev/null&& make install > /dev/null

echo "install zlib over"

cd ..

pcredir=${basedir}/nginx/pcre-8.42
zlibdir=${basedir}/nginx/zlib-1.2.11
openssldir=${basedir}/nginx/openssl-1.1.1-pre8

echo "begin to install ngnix"

tar -zxf nginx-1.15.7.tar.gz
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
--with-pcre=${pcredir} \
--with-zlib=${zlibdir} \
--with-openssl=${openssldir} > /dev/null
make -j 4 > /dev/null && make install > /dev/null

cp ${basedir}/service_nginx.sh /etc/init.d/nginx

chmod a+x /etc/init.d/nginx
chkconfig --add nginx
chkconfig nginx on

echo "install ngnix over"

cd ${basedir}

echo "begin to install keepalived"
tar -zxvf keepalived-2.0.20.tar.gz

cd keepalived-2.0.20/

export LIBRARY_PATH=/usr/local/lib64
./configure > /dev/null
make -j 4 > /dev/null && make install > /dev/null

cp keepalived/etc/init.d/keepalived /etc/init.d/
chmod a+x /etc/init.d/keepalived
chkconfig --add keepalived

chkconfig keepalived on

sed -i "s/KEEPALIVED_OPTIONS=\"-D\"/KEEPALIVED_OPTIONS=\"-D -f /usr/local/etc/keepalived/keepalived.conf\"" /usr/local/etc/sysconfig/keepalived

sed -i "s@-D\"@-D -f /usr/local/etc/keepalived/keepalived.conf\"@g" /usr/local/etc/sysconfig/keepalived

cp ${basedir}/nginx_check.sh /usr/local/etc/keepalived/nginx_check.sh

chmod a+x /usr/local/etc/keepalived/nginx_check.sh

echo "install keepalived over"