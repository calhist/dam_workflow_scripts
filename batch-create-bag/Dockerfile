FROM ubuntu:18.04

ARG FITS_VERSION="1.4.1"
ARG FITS_URL="https://github.com/harvard-lts/fits/releases/download/$FITS_VERSION/fits-$FITS_VERSION.zip"

RUN apt-get -y update && \
    apt-get -y install unzip xmlstarlet openjdk-8-jdk exiftool curl python

RUN curl -s -o get-pip.py https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py && \
    pip install awscli bagit --upgrade

WORKDIR /opt/fits

RUN curl -sLo fits.zip $FITS_URL && \
    unzip fits.zip && \
    rm fits.zip

WORKDIR /tmp

ADD create-bag.sh /usr/local/bin/create-bag.sh

RUN chmod 0755 /usr/local/bin/create-bag.sh

ENTRYPOINT ["/usr/local/bin/create-bag.sh"]
