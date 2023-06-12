#!/bin/bash
function build_layer()
{
	if [ $AGENT = "java" ];
	then
	build-java-x86
	elif [ $AGENT = "python" ];
	then
	build-python38-x86
	fi
}

function build-java-x86() 
{
	echo "Building cavisson layer for java (x86_64)"
	rm -rf $BUILD_DIR $AGENT_DIST_X86_64
	mkdir $BUILD_DIR
	tar -xvzf $NETDIAGNOSTIC_BUILD -C $BUILD_DIR/
	zip -r $AGENT_DIST_X86_64 $BUILD_DIR
	rm -rf $BUILD_DIR
}

function build-python38-x86() 
{
    echo "Building cavisson layer for python3.8 (x86_64)"
    rm -rf $BUILD_DIR $AGENT_DIST_X86_64
    pip install --target $BUILD_DIR -r requirements.txt > /dev/null 2>&1
    pip install --target $BUILD_DIR pythonagent > /dev/null 2>&1
    zip -r $AGENT_DIST_X86_64 $BUILD_DIR > /dev/null
    rm -rf $BUILD_DIR
}

function publish_layer() 
{
   
    if [ ! -f $AGENT_DIST_X86_64 ]; then
        echo "Package not found: ${AGENT_DIST_X86_64}"
        exit 1
    fi

    py38_hash=$(md5sum $AGENT_DIST_X86_64 | awk '{ print $1 }')
    
    py38_s3key="cav-python3.8/${py38_hash}.x86_64.zip"
    
    for region in "${REGIONS_ARCH[@]}"; do
        aws s3api get-bucket-location --bucket ${BUCKET_NAME} || aws s3 mb s3://${BUCKET_NAME} --region us-west-2 
        echo $BUCKET_NAME 
        
        aws --region $region s3 cp $AGENT_DIST_X86_64 "s3://${BUCKET_NAME}/${py38_s3key}" 
        echo "Uploading ${AGENT_DIST_X86_64} to s3://${BUCKET_NAME}/${py38_s3key}"
        
        echo "Publishing $compatibleruntimes layer to ${region}"
       

       layer_version=$(aws lambda publish-layer-version \
            --layer-name $layer_name \
            --content "S3Bucket=${BUCKET_NAME},S3Key=${py38_s3key}" \
            --description "Cavisson Layer for $compatibleruntimes (x86_64)" \
            --license-info "Apache-2.0" \
            --compatible-runtimes $compatibleruntimes \
            #--compatible-architectures "x86_64" \
            #--region $region \
           # --output text \
           # --query Version
	)

        echo "published $compatibleruntimes layer version ${layer_version} to ${region}"

        echo "Setting public permissions for $compatibleruntimes layer version ${layer_version} in ${region}"
        
        layer_version=1

        aws lambda add-layer-version-permission \
	    --layer-name ${layer_name} \
	    --statement-id publi5 \
	    --action lambda:GetLayerVersion  \
	    --principal "*" \
	    --version-number ${layer_version} --region ${region}

 
        
        
        echo "Attaching layer ${layer_name} version ${layer_version} to customer function ${cust_func_name}"
	if [ $AGENT = "java" ];
	then
	aws lambda update-function-configuration --function-name ${cust_func_name} \
           --layers arn:aws:lambda:${region}:${account_id}:layer:${layer_name}:${layer_version} \
           --handler ${cavisson_lambda_handler} \
            --environment ${env_str}
	elif [ $AGENT = "python" ];
	then
	aws lambda update-function-configuration --function-name ${cust_func_name} \
           --layers arn:aws:lambda:${region}:${account_id}:layer:${layer_name}:${layer_version} \
           --handler ${runtime_handler} \
            --environment ${env_str}
	fi

    done
}

function change_handler(){
             
        echo "change the handler at customer function ${cust_func_name}"
        aws lambda update-function-configuration --function-name ${cust_func_name} \
            --handler ${cavisson_lambda_handler}

}

function detach_all_layers(){
        read -p "cust_func_name              :" cust_func_name
        if [ -z ${cust_func_name} ]
        then
            echo "please enter the correct cust_func_name"
            help
            exit 1
        fi
        cavisson_lambda_handler=$(aws lambda get-function-configuration --function-name  ${cust_func_name} --output text --query ['Handler'])
        if [ $cavisson_lambda_handler==$runtime_handler ]
        then
            echo "inside then " 
            cavisson_lambda_handler=$(aws lambda get-function-configuration --function-name  ${cust_func_name} --query [Environment.Variables.CAVISSON_LAMBDA_HANDLER] --output text)
        echo "cavisson_lambda_handlerinside if        ${cavisson_lambda_handler}"
        fi
        
        echo "detach_all_layers in customer function ${cust_func_name}"
        aws lambda update-function-configuration --function-name ${cust_func_name} \
             --layers  

}
function read_arguments()
{

    read -p "BUCKET_NAME                 :" BUCKET_NAME
    if [ -z  ${BUCKET_NAME} ]
    then
        echo "please enter the correct BUCKET_NAME"
        help
        exit 1
    fi


   #read -p "layer_name" layer_name
    read -p "account_id                  :" account_id
    if [ -z  ${account_id} ]
    then
        echo "please enter the correct account_id"
        help
        exit 1
    fi


    read -p "cust_func_name              :" cust_func_name
    if [ -z ${cust_func_name} ]
    then
        echo "please enter the correct customer function name"
        help
        exit 1
    fi

    read -p "gateway_ip                  :" cav_app_agent_proxyip
    if [ -z ${cav_app_agent_proxyip} ]
    then
        echo "please enter the correct proxy or ndc ip"
        help
        exit 1
    fi


    read -p "gateway_port                :" cav_app_agent_proxyport
    if [ -z ${cav_app_agent_proxyport} ]
    then
        echo "please enter the correct proxy or ndc port"
        help
        exit 1
    fi

    #read -p "cavisson_lambda_handler     :" cavisson_lambda_handler
    #if [ -z ${cavisson_lambda_handler} ]
    #then
    #    echo "please enter the correct cavisson_lamda_handler"
    #    help
    #    exit 1
    #fi

    cavisson_lambda_handler=$(aws lambda get-function-configuration --function-name  ${cust_func_name} --output text --query ['Handler'])
    echo "cavisson_lambda_handler        ${cavisson_lambda_handler}"


	if [ $AGENT = "java" ];
	then
	    read_java_arguments
	elif [ $AGENT = "python" ];
	then
	    read_python_arguments
	fi

}

function read_java_arguments()
{
    read -p "tier                :" cav_app_agent_tier
    if [ -z ${cav_app_agent_tier} ]
    then
        echo "please enter the correct tier name"
        help
        exit 1
    fi
 	
	env_str="{\"Variables\":{\"JAVA_TOOL_OPTIONS\":\"-javaagent:/opt/netdiagnostics/lib/ndmain.jar=time,ndAgentJar=/opt/netdiagnostics/lib/ndagent-with-dep.jar,ndHome=/opt/netdiagnostics,spLogs=6,logInstrCode=0,tier=${cav_app_agent_tier},server=S,instance=${cust_func_name},AgentLoggingMode=ALL,ndcHost=${cav_app_agent_proxyip},ndcPort=${cav_app_agent_proxyport}\",\"ndHome\":\"/opt/netdiagnostics/\"}}"

}

function read_python_arguments()
{
    read -p "PY_VER                      : " PY_VER
    if [ -z  ${PY_VER} ]
    then
        echo "please enter the correct Python Version"
        help
        exit ;
    fi
    read -p "cav_app_agent_env           :" cav_app_agent_env
    if [ -z ${cav_app_agent_env} ]
    then
        echo "please enter the correct cav_app_agent_env"
        help
        exit 1
    fi


    read -p "cav_app_agent_logginglevel  :" cav_app_agent_logginglevel
    if [ -z ${cav_app_agent_logginglevel} ]
    then
        echo "please enter the correct cav_app_agent_loginglevel"
        help
        exit 1
    fi

    #read -p "runtime_handler             :" runtime_handler
    #if [ -z ${runtime_handler} ]
    #then
    #    echo "please enter the correct Python runtime_handler"
    #    help
    #    exit 1
    #fi

    if [ $cavisson_lambda_handler==$runtime_handler ]
    then
        echo "inside then " 
        cavisson_lambda_handler=$(aws lambda get-function-configuration --function-name  demoFunction --query [Environment.Variables.CAVISSON_LAMBDA_HANDLER] --output text)
    echo "cavisson_lambda_handlerinside if        ${cavisson_lambda_handler}"
    fi 

	env_str="{\"Variables\":{\"CAVISSON_LAMBDA_HANDLER\":\"${cavisson_lambda_handler}\",\"CAV_APP_AGENT_Env\":\"${cav_app_agent_env}\",\"CAV_APP_AGENT_LoggingLevel\":\"${cav_app_agent_logginglevel}\",\"CAV_APP_AGENT_ProxyIP\":\"${cav_app_agent_proxyip}\",\"CAV_APP_AGENT_ProxyPort\":\"${cav_app_agent_proxyport}\"}}"

}

function write_arguments()
{
echo "AGENT_DIST_X86_64: ${AGENT_DIST_X86_64}"
echo ${REGIONS_ARCH[@]}
echo ${BUCKET_NAME}
}


function help()
{
echo
echo "To attach layer pass agent type in argument i.e. java or python"
echo "example 'bash <script-name.sh> java"
echo " by default , when no options are given, it attaches the layer  i.e. 
if we run this script with 'bash <script-name.sh>',then it attaches the layers\n"
echo -e  "attach layer\n "
echo -e  "for attaching or de_attaching layers ,these are the required arguments ::\n"
echo -e  " PY_VER                       python version\n"
echo -e  "BUCKET_NAME                   bucket name (provided by cavisson)\n"
echo -e  "account_id                    user account id\n"
echo -e  "cust_func_name                user function name\n"
#echo -e  "runtime_handler               runtime handler\n"
#echo -e  "cavvisson_lamda_handler       cavisson lamda handler\n"
echo -e  "cav_app_agent_env             cav_app_agent environment( provided by cavisson)\n"
echo -e  "cav_app_agent_logginglevel    logginglevel\n"
echo -e  "gateway_ip                    proxy ip or ndc host\n"
echo -e  "gateway_port                  proxy port or ndc port\n"
echo -e  "tier                          tier name\n"

echo -e "-h                           :Enter -h for help\n"
echo -e "-d                           :Enter -d for de-attaching the layers\n"

}



####################################f
#  PROGRAM BEGIN HERE
#############################################

set -Eeuo pipefail

while getopts ":hd" option; do
   echo "Inside while"
   case $option in
      h) # display Help
         echo -e "help!!!!!\n"
         help
         exit;;
     d)#de_attach layer
        #read_arguments
        detach_all_layers
        change_handler 
         exit;;
     
     \?) # Invalid option
         echo "Error: Invalid option selected"
         exit;;
   esac
done
AGENT=$1
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REGIONS_ARCH=(
  us-west-2
)

if [ "$AGENT" == "java" ];
then
	echo "javaagent"
	BUILD_DIR=netdiagnostics
	NETDIAGNOSTIC_BUILD=netdiagnostics.tar.gz
	AGENT_DIST_X86_64=netdiagnostics.zip
	layer_name=cavisson_java_agent
	compatibleruntimes="java11"
elif [ "$AGENT" == "python" ];
then 
	echo "pythonagent"
	BUILD_DIR=python
	AGENT_DIST_X86_64=python.zip
	cav_app_agent_env=AWS_LAMBDA
	layer_name=cavisson_python_agent
	runtime_handler=/opt/python/pythonagent/bootstrap/cavagent_lambda_wrapper.handler
	compatibleruntimes="python3.8"
else
	echo "Error: Incorrect Agent Type passed. Available options : [java,python]"
	help
            	exit 1
fi

read_arguments
write_arguments
build_layer
publish_layer



