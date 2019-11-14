FROM bash:5

ADD generate_kubeconfig.sh /usr/bin/generate_kubeconfig.sh

RUN apk add curl && \
    curl -#ksSL "https://ndp-pub.nos-jd.163yun.com/dl/tools/kubernetes-client-v1.14.0-linux-amd64.tar.gz" | tar -zx -C /usr/ && \
    curl -#kssL -o cfssl_linux-amd64 https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 && \
    curl -#kssL -o cfssljson_linux-amd64 https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 && \
    curl -#kssL -o cfssl-certinfo_linux-amd64 https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 && \
    chmod +x cfssl_linux-amd64 cfssljson_linux-amd64 cfssl-certinfo_linux-amd64 && \
    mv cfssl_linux-amd64 /usr/local/bin/cfssl && \
    mv cfssljson_linux-amd64 /usr/local/bin/cfssljson && \
    mv cfssl-certinfo_linux-amd64 /usr/bin/cfssl-certinfo && \
    ln -s /usr/kubernetes/client/bin/kubectl /usr/bin/ && \
    ln -svf /usr/bin/generate_kubeconfig.sh /usr/bin/generate_kubeconfig

CMD ["generate_kubeconfig", "--help"]