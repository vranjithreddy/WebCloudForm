#!/bin/bash

set -e
set -x

check4template() {
    templateName="$1"
    cfTemplate="${WORKSPACE}/cloudformation/${templateName}.template"
    [[ -e "${cfTemplate}" ]]
}

## validates the cloud formation template after checking for files
validateCloudFormation(){
    templateName="$1"
    cfTemplate="${WORKSPACE}/cloudformation/${templateName}.template"

    ## Check to see if the CloudFormation template files exist in the CloudFormation directory and run the validate-stack command
    echo "[INFO] Validating CloudFormation template file \"${cfTemplate}\"."
    if [ $(ls "${cfTemplate}" > /dev/null 2>&1; echo $?) -eq 0 ]; then
        if [ $(aws --region=us-east-2 cloudformation validate-template --template-body file://${cfTemplate} > /dev/null 2>&1; echo $?) -ne 0 ]; then
            echo "[ERRO] Validation failure on CloudFormation template \"${cfTemplate}\"."
            exit 1
        fi
    else
        echo "[ERRO] Can't find CloudFormation template file \"${cfTemplate}\"."
        exit 1
    fi
}

## This function will deploy CloudFormation stacks
runCloudFormation() {
    cfName="$1"
    cfTemplate="${WORKSPACE}/cloudformation/${cfName}.template"

    cfStackName="${cfName}"

    if [ $(aws --region=us-east-2 cloudformation describe-stacks --stack-name "${cfStackName}" > /dev/null 2>&1 ; echo "$?") -ne 0 ]; then
        action="create-stack"
    else
        action="update-stack"
    fi

    echo "[INFO] Executing CloudFormation Stack:"
    echo "[INFO]  CloudFormation Stack Action: ${action}"
    echo "[INFO]  CloudFormation Stack Name: ${cfStackName}"
    echo "[INFO]  CloudFormation Template Location: ${cfTemplate}"
    set +e
    aws --region=us-east-2 cloudformation ${action} \
        --stack-name ${cfStackName} \
        --template-body file://${cfTemplate} \
        --capabilities CAPABILITY_IAM \
        --capabilities CAPABILITY_NAMED_IAM > >(tee ${WORKSPACE}/CFstdout.log) 2> >(tee ${WORKSPACE}/CFstderr.log >&2)
    RC=$?

    set -e
    checkCFStatus ${cfStackName}

}



## This function will check the status of CloudFormation stack deployment
checkCFStatus(){
        checkCFStatusTimeout=7200
    checkCFStatusStart=0
    stackName=$1

    if [ "$RC" -eq 0 ]; then
        echo "[INFO] CloudFormation was successfully executed, continuing to collect status."
    elif [ "$RC" -ne 0 ] && [ $(grep 'No updates are to be performed' ${WORKSPACE}/CFstderr.log > /dev/null 2>&1; echo $?) -eq 0 ]; then
        echo "[INFO] No CloudFormation update-stack needed."
        return
    else
        echo "[ERRO] CloudFormation Failed, exiting."
        exit 1
    fi

    while [ ${checkCFStatusStart} -le ${checkCFStatusTimeout} ]; do
        CFStatus=$(aws --region=us-east-2 cloudformation describe-stacks --stack-name ${stackName} |grep "\"StackStatus\":")
        if [[ "${CFStatus}" == *"CREATE_COMPLETE"* ]];then
            echo "CloudFormation Create Completed Successfully."
            return
        elif [[ "${CFStatus}" == *"UPDATE_COMPLETE"* ]]; then
            echo "CloudFormation Update Completed Successfully."
            return
        elif [[ "${CFStatus}" == *"ROLLBACK_COMPLETE"* ]];then
            echo "[ERRO] An error occurred when running the CloudFormation Stack. Displaying the CloudFormation Stack Events."
            aws --region=us-east-2 cloudformation describe-stack-events --stack-name ${stackName} --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].ResourceStatusReason' --output text
            echo "[ERRO] CloudFormation Failed, exiting."
            exit 1
        fi

        checkCFStatusStart=$(echo ${checkCFStatusStart} + 10 |bc)
        echo "[INFO] Checking CloudFormation status again in 10 seconds."
        sleep 10
    done

    echo "[WARN] CheckCFStatus Timeout was reached exiting..."
    exit 1
}

###########
## MAIN ##
##########

##set variables
DATE=$(date +%Y%m%d%H%M)
checkCFStatusTimeout=1200
export PATH=~/.local/bin:$PATH
check4template webinstance && validateCloudFormation webinstance
if check4template webinstance; then
runCloudFormation webinstance
fi



