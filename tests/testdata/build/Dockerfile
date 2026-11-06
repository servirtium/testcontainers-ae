FROM alpine:3
ARG GREETING=hello
COPY greet.sh /usr/local/bin/greet.sh
COPY sub/data.txt /data.txt
RUN chmod +x /usr/local/bin/greet.sh && echo "$GREETING" > /greeting
CMD ["/usr/local/bin/greet.sh"]
