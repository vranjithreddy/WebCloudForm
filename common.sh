getFromStore() {
    paramName="$1"
    val=$(aws ssm get-parameters --with-decryption --names $paramName --query 'Parameters[0].Value' --output text)
    echo -n "$val"
}

putInStore() {
    paramName="$1"
    paramValue="$2"
    storeParamName=$(getStoreParamName "$paramName")
    aws ssm put-parameter \
        --name "$storeParamName" \
        --value "$paramValue" \
        --overwrite \
        --type String
    if [ $? = 0 ]; then
        echo "[INFO] KV pair added to ParameterStore: $storeParamName=$paramValue"
    else
        echo "[ERRO] Unable to add KV pair to ParameterStore: $storeParamName=$paramValue"
    fi
}
