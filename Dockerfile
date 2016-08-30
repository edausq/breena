FROM perl:5.24.0

RUN apt-get update && apt-get install -y libpoe-component-sslify-perl && rm -rf /var/lib/apt/lists/*

COPY . /opt/breena

WORKDIR /opt/breena

RUN /opt/breena/install_modules

RUN useradd -ms /bin/bash breena

USER breena

ENV PERL5LIB /usr/local/lib/perl5/site_perl/5.24.0

CMD ["/opt/breena/breena", "/etc/breena/breena.conf"]
