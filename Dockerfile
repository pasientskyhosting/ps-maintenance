FROM alpine:3.5
MAINTAINER Andreas Krüger <ak@patientsky.com>

RUN apk add --no-cache bash

ENTRYPOINT ["bash"]
