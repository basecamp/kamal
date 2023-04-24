FROM registry

COPY boot.sh .

RUN ln -s /shared/certs /certs

ENTRYPOINT ["./boot.sh"]
