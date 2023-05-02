FROM registry

COPY boot.sh .

RUN ln -s /shared/certs /certs

HEALTHCHECK --interval=1s CMD pgrep registry

ENTRYPOINT ["./boot.sh"]
