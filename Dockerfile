FROM debian:latest

ENV HOME /home/x0dbot
ENV HOSTNAME x0dbot.local
ENV LANG en_US.utf8
ENV X0DBOT_VERSION 2.0.0

# install base package and dependencies
RUN apt-get update && rm -rf /var/lib/apt/lists/*

RUN packages=' \
		autoconf \
		automake \
		bzip2 \
		ca-certificates \
        cpanminus \
		cron \
		dirmngr \
		dpkg-dev \
		git \
		gnupg \
		htop \
		less \
		libglib2.0-0 \
		libglib2.0-dev \
		libncurses-dev \
		libssl-dev \
		libtool \
		lynx \
		make \
		net-tools \
		pkg-config \
		sudo \
        mariadb-server \
		wget \
		vim \
		xz-utils \
	' \
	&& set -x \
	&& apt-get update && apt-get install -y $packages --no-install-recommends

RUN echo "x0dbot ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/90-x0dbot

# configure mysql db+user
RUN sed 's/bind-address/#bind-address/g' /etc/mysql/mariadb.conf.d/50-server.cnf
RUN service mysql start && mysql -u root -e "create database x0dbot; create user x0dbot identified by 'x0dbot'; grant all on x0dbot.* to x0dbot;"

# configure system user account
RUN useradd -rm -d $HOME -s /bin/bash -g root -G sudo -u 1000 x0dbot -p "$(openssl passwd -1 x0dbot)"
USER x0dbot
WORKDIR $HOME

# setup x0dbot
RUN sudo service mysql start \
	&& git clone https://github.com/sodonnell/x0dbot.git \
	&& cd x0dbot \
	&& git checkout docker \
	&& git pull origin docker \
	&& bash setup.sh

CMD ["-c","$HOME/x0dbot/xodbot.pl"]
