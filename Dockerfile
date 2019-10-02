FROM kennethheung/pointbase:latest

# setup environment variables
#   which pickup up from either docker build
#   or wrecker env
ARG OCIUSEROCID
ARG OCIAPIKEYFP
ARG OKEY
ARG OCITENANTOCID
ARG ATPOCID
ARG ENDPOINT
# oracle DB specific env
ENV LD_LIBRARY_PATH="/opt/oracle/instantclient_19_3"
ENV TNS_ADMIN="/reward/wallet/"
ENV WALLET_LOCATION="/reward/wallet/"

# install all required dependencies and create subdir
RUN mkdir -p /reward
WORKDIR /reward
COPY . .

RUN cd /reward \
  && chmod 700 /reward/dl.wallet.sh \
  && cp temp.pem temp2.pem \
  && export HELL="$(awk 'BEGIN {} {file=file$0"\n"} END {print file}' temp2.pem | sed -e 's/\\n/ /g')" \
  && echo $HELL > temp3.pem \
  && sed -i 's/-----BEGIN RSA PRIVATE KEY----- //g' /reward/temp3.pem \
  && sed -i 's/ -----END RSA PRIVATE KEY-----/\n/g'   /reward/temp3.pem \
  && echo "-----BEGIN RSA PRIVATE KEY-----" > /reward/ociapikey.pem \
  && echo "$(cat /reward/temp3.pem)" >> /reward/ociapikey.pem \
  && echo "-----END RSA PRIVATE KEY-----" >> /reward/ociapikey.pem \
  && chmod 600 /reward/ociapikey.pem \
  && export ENDPOINT=$OCIENDPOINT  \
  && export OCIUSEROCID=$OCIUSEROCID  \
  && export OCIAPIKEYFP=$OCIAPIKEYFP  \
  && export OCITENANTOCID=$OCITENANTOCID  \
  && export OCIREGION=$OCIREGION  \
  && echo "getting wallet from ATP..."  \
  && /reward/dl.wallet.sh $ATPOCID  \
  && unzip -d wallet ./wallet.zip \
  && sed -i 's/?\/network\/admin/$TNS_ADMIN/g'  /reward/wallet/sqlnet.ora \
  && npm install \
  && grunt build:release
# we should remove the keyfile from the image
EXPOSE 80
CMD ["node","server.js"]
