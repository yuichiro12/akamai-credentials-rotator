FROM akamai/httpie:v2.4.0
RUN apk add --no-cache aws-cli jq bash
COPY . /workdir
CMD ./rotate.sh
