FROM ubuntu:18.04
########################################
# Update Base System and install nginx #
########################################

RUN apt-get update && apt-get upgrade -y
RUN apt-get install wget -y
RUN cd /tmp/ && wget http://nginx.org/packages/ubuntu/pool/nginx/n/nginx/nginx_1.16.1-1~bionic_amd64.deb && apt install /tmp/nginx_1.16.1-1~bionic_amd64.deb -y && apt-mark hold nginx

##############################################
# Install Build Dependancies for modsecurity #
##############################################

RUN apt-get install autoconf m4 gnupg2 ca-certificates lsb-release libtool build-essential libpcre3-dev zlib1g-dev libssl-dev libxml2-dev libgeoip-dev libyajl-dev libcurl4-openssl-dev libpcre++-dev pkgconf libxslt1-dev libgd-dev git -y

#######################
# Install modsecurity #
#######################

RUN mkdir /opt/ModSecurity/ && \
cd /opt/ && \
git clone --depth 100 https://github.com/SpiderLabs/ModSecurity.git && \
cd /opt/ModSecurity && \
git submodule init && \
git submodule update && \
chmod +x /opt/ModSecurity/build.sh && \
/opt/ModSecurity/build.sh && \
/opt/ModSecurity/configure && \
cd /opt/ModSecurity && \
make && \
make install

#######################################
# Install modsecurity nginx connector #
#######################################

RUN cd /tmp/ && \
wget http://nginx.org/download/nginx-1.16.1.tar.gz && \
tar -xvf /tmp/nginx-1.16.1.tar.gz && \
git clone https://github.com/SpiderLabs/ModSecurity-nginx && \
cd /tmp/nginx-1.16.1/ && \
./configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt='-g -O2 -fdebug-prefix-map=/data/builder/debuild/nginx-1.16.1/debian/debuild-base/nginx-1.16.1=. -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' --add-dynamic-module=/tmp/ModSecurity-nginx/ && \
make modules && \
cp /tmp/nginx-1.16.1/objs/ngx_http_modsecurity_module.so /etc/nginx/modules/ngx_http_modsecurity_module.so && \
cd /tmp/ && \
rm -rf *

####################################
# Install modsecurity core ruleset #
####################################

RUN mkdir /etc/nginx/modsec && \
cd /etc/nginx/modsec/ && \
git clone https://github.com/SpiderLabs/owasp-modsecurity-crs.git && \
mv /etc/nginx/modsec/owasp-modsecurity-crs/crs-setup.conf.example /etc/nginx/modsec/owasp-modsecurity-crs/crs-setup.conf && \
cp /opt/ModSecurity/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf && \
touch /etc/nginx/modsec/main.conf && \
echo "Include /etc/nginx/modsec/modsecurity.conf" >> /etc/nginx/modsec/main.conf && \
echo "Include /etc/nginx/modsec/owasp-modsecurity-crs/crs-setup.conf" >> /etc/nginx/modsec/main.conf && \
echo "Include /etc/nginx/modsec/owasp-modsecurity-crs/rules/*.conf" >> /etc/nginx/modsec/main.conf && \
cp /opt/ModSecurity/unicode.mapping /etc/nginx/modsec/

############################
# Clean Build Dependencies #
############################

RUN apt-get autoremove autoconf m4 gnupg2 ca-certificates lsb-release libtool build-essential libpcre3-dev zlib1g-dev libssl-dev libxml2-dev libgeoip-dev libyajl-dev libcurl4-openssl-dev libpcre++-dev pkgconf libxslt1-dev libgd-dev git -y

RUN apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*
    
###############################
# Remove nginx user directive #
###############################

RUN sed -i.bak 's/^user/#user/' /etc/nginx/nginx.conf

#################################
# Test nginx config and restart #
#################################

RUN nginx -t && service nginx restart

###########
# Runtime #
###########
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80
EXPOSE 443
CMD ["nginx", "-g", "daemon off;"]
