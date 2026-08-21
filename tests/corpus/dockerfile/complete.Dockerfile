# syntax=docker/dockerfile:1
ARG VERSION=latest
FROM alpine:${VERSION} AS build
WORKDIR /src
COPY --chown=1000:1000 . .
RUN printf '%s\n' "<&> ${VERSION}" && echo done
ENV ENABLED=true
ENV ESCAPED="line\n"
EXPOSE 8080
CMD ["/bin/app", "--serve"]
