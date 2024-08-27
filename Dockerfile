FROM quay.io/operator-framework/ansible-operator:v1.35.0

COPY requirements.yml ${HOME}/requirements.yml
RUN ansible-galaxy collection install -r ${HOME}/requirements.yml \
 && chmod -R ug+rwx ${HOME}/.ansible
RUN bash -c "curl -s https://get.helm.sh/helm-v3.15.4-linux-amd64.tar.gz > helm3.tar.gz" \
&&  tar -zxvf helm3.tar.gz linux-amd64/helm && chmod +x linux-amd64/helm \
&&  mv linux-amd64/helm /usr/local/bin/helm && rm helm3.tar.gz && rm -R linux-amd64

COPY watches.yaml ${HOME}/watches.yaml
COPY roles/ ${HOME}/roles/
COPY playbooks/ ${HOME}/playbooks/
