#!/usr/bin/env bash

# temporary script in place until https://github.com/UKHomeOffice/kb8or/issues/93 if fixed
APP_PREFIX='fm-ui'
RC='rc/pttg-ip-'"${APP_PREFIX}"
RCFILE='k8resources/pttg-family-migration-fm-ui-rc.yaml'
RCTIMEOUT='5m'
APPNAME='pttg-income-proving-'"${APP_PREFIX}"
NAMESPACE='pt-i-dev'
# putting the token in plaintext here is very ugly, had to be done in a hurry
# find a better way to do it
KUBECTL_FLAGS='-s https://kube-dev.dsp.notprod.homeoffice.gov.uk --insecure-skip-tls-verify=true --namespace='"${NAMESPACE}"' --token=0225CE5B-C9C8-4F3B-BE49-3217B65B41B8'

SVC='svc/pttg-ip-'"$APP_PREFIX"
SVCFILE='k8resources/pttg-family-migration-fm-ui-svc.yaml'
SVC_NODE_PORT_FILE='environments/dev.yaml'

function rc() {
  echo "=== deploying RC: ${RC}"
  sed -i 's|${.*pt-income-version.*}|'"${VERSION}"'|g' ${RCFILE}
  sed -i 's|${.*pttg_income_proving_fm_ui_port.*}|'"$SVC_NODE_PORT"'|g' $SVCFILE
  ./kubectl ${KUBECTL_FLAGS} get ${RC} 2>&1 |grep -q "not found"
  if [[ $? -eq 1 ]];
  then
      echo "=== updating the ${APPNAME} RC ..."
      ./kubectl ${KUBECTL_FLAGS} delete ${RC}
  else
      echo "=== ${APPNAME} RC doesn't exist, therefore I don't need to delete it, moving on ..."
  fi
  ./kubectl ${KUBECTL_FLAGS} create -f ${RCFILE}

  echo "=== waiting for the pods in the RC: ${RC} to go into the running state === timeout:${RCTIMEOUT}"
  checkRc
}

function checkRc(){
  # we want to capture the RC with no pods in waiting/failed state
  # Pods Status:    1 Running / 0 Waiting / 0 Succeeded / 0 Failed
  # and still continue waiting if the RC has any pods waiting
  # Pods Status:    1 Running / 1 Waiting / 0 Succeeded / 0 Failed
  local POD_STATUS='empty'
  local RC_STATUS='empty'
  while true
  do
    RC_STATUS=$(kubectl ${KUBECTL_FLAGS} get ${RC} | grep ${APPNAME} | awk '{print $1}')
    if [[ "${RC_STATUS}" != "${APPNAME}" ]];
    then
      sleep 0.5
    else
      break
    fi
  done
  while true
  do
    while true
    do
      POD_STATUS=$(kubectl ${KUBECTL_FLAGS} describe ${RC} | grep "Pod.*Status")
      if [[ "${POD_STATUS}" != ' ' ]] && [[ "${POD_STATUS}" != 'empty' ]];
      then
        break
      fi
    done
    # typecasting in bash
    RUNNING_PODS=$(($(echo "${POD_STATUS}" | awk '{print $3" "$4}' | awk '{print $1}') + 0))
    WAITING_PODS=$(($(echo "${POD_STATUS}" | awk '{print $6" "$7}' | awk '{print $1}') + 0))

    if [[ ${RUNNING_PODS} -gt 0 ]] \
      && \
     [[ ${WAITING_PODS} -eq 0 ]];
    then
      echo "pods inside RC: ${RC} have been deployed succesfully"
      break
    else
      sleep 0.5
    fi
  done

  echo "=== current status of the RC ${RC} : "
  kubectl ${KUBECTL_FLAGS} describe ${RC} |grep "Pod.*Status" -B2
}

function svc(){
  local SVC_NODE_PORT=`grep pttg_income_proving_fm_ui_port "${SVC_NODE_PORT_FILE}" | awk '{print $2}'`
  # typecasting in bash
  SVC_NODE_PORT=$((${SVC_NODE_PORT} + 0))

  echo "=== deploying SVC: ${SVC}"
  sed -i 's|${.*pttg_income_proving_fm_ui_port.*}|'"$SVC_NODE_PORT"'|g' $SVCFILE
  ./kubectl ${KUBECTL_FLAGS} get ${SVC} 2>&1 |grep -q "not found"
  if [[ $? -eq 1 ]];
  then
      echo "=== updating the ${APPNAME} SVC ..."
      ./kubectl ${KUBECTL_FLAGS} delete ${SVC}
  else
      echo "=== ${APPNAME} SVC doesn't exist, therefore I don't need to update it, moving on ..."
  fi
  ./kubectl ${KUBECTL_FLAGS} create -f ${SVCFILE}
  echo "=== current status of the SVC ${SVC} : "
  kubectl ${KUBECTL_FLAGS} describe ${SVC}

}

# main
echo "=== current version of ${APPNAME} coming from the upstream build job is VERSION=$VERSION"
if [[ -f ./kubectl ]]
then
    echo "kubectl already downloaded, moving on ..."
    chmod 755 ./kubectl
else
    echo "downloading kubectl"
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubectl"
    chmod 755 ./kubectl
fi

rc
svc
