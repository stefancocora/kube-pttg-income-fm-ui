FROM quay.io/ukhomeofficedigital/kb8or:v0.6.13
WORKDIR /var/lib/app_deploy
ADD ./ ./
ENTRYPOINT ["./scripts/deploy"]
