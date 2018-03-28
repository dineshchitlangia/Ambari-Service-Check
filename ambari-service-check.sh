usage() {
echo "
This script triggers service checks for components which are not in maintenance mode
Usage: sh ambari-service-check.sh -u <user> -p <password> -s <all|comma-separated list> [-t <ambariServerHost>] [-n <ambariServerPort>] [-c <empty | path to PEM file>] \n
If not specified, default value for -t : localhost
If not specified, default value for -p : 8080(when SSL disabled) and 8443(when SSL enabled)

Example: Trigger Service Check for all components which are not in Maintenance Mode
sh ambari-service-check.sh -u admin -p admin -s all

Example: Trigger Service Check for only for HIVE, HDFS, and KNOX
sh ambari-service-check.sh -u admin -p admin -s hive,hdfs,knox

Example: Trigger Service Check for only for HIVE, HDFS, and KNOX when ssl is enabled
sh ambari-service-check.sh -u admin -p admin -s hive,hdfs,knox -c

Example: Trigger Service Check for only for HIVE, HDFS, and KNOX when ssl is enabled and you want to specify PEM file
sh ambari-service-check.sh -u admin -p admin -s hive,hdfs,knox -c /path/to/pem/file

" 1>&2; exit 1;
}

sslEnabled=false;
result='';
certPath='';
sslFlag='';

while getopts "u:p:s:t::n::c" opt; do
    case "${opt}" in
        u)
            ambariUser=${OPTARG}
            if [ $ambariUser = "" ]; then
                  usage
            fi
            ;;
        p)
            ambariPassword=${OPTARG}
            if [ $ambariPassword = "" ]; then
                  usage
            fi
	    	;;
        t)
            ambariHost=${OPTARG}
	    	;;
        n)
            ambariPort=${OPTARG}
            ;;
        s)
            serviceCheck=`echo ${OPTARG} | tr [a-z] [A-Z]`
            if [ -z "$serviceCheck" ]; then
				usage
            fi
            ;;
		c)
	    	sslEnabled=true;
	    	;;

        *)
	    	echo "Invalid option specified."
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# Set Default Values
if [ sslEnabled ]; then
	certPath=$1
    if [ -z "$certPath" ]; then
        sslFlag=" -k "
    else
        sslFlag=" --cacert $certPath ";
    fi
fi

if [ -z "$ambariHost" ]; then
	ambariHost=`hostname`
fi

if $sslEnabled; then
	if [ -z "$ambariPort" ]; then
		ambariPort="8443"
	fi
	ambariURL="https://$ambariHost:$ambariPort";
else
	if [ -z "$ambariPort" ]; then
        	ambariPort="8080"
	fi
	ambariURL="http://$ambariHost:$ambariPort";
fi

if [ -z "$clusterName" ]; then
	result=`curl $sslFlag  -s -u $ambariUser:$ambariPassword "$ambariURL/api/v1/clusters"`;
	if [ -z "$result" ] ; then
		echo "Error: The following command did not yield results."
		echo "curl $sslFlag -s -u $ambariUser:$ambariPassword \"$ambariURL/api/v1/clusters\""
		exit;
	fi
	clusterName=`curl $sslFlag  -s -u $ambariUser:$ambariPassword "$ambariURL/api/v1/clusters" | python -mjson.tool | perl -ne '/"cluster_name":.*?"(.*?)"/ && print "$1\n"'`;
fi



#Prepare list of services for which checks should be triggered

if [ "$serviceCheck" == "ALL" ] ; then
	aliveServices=`curl $sslFlag -s -u $ambariUser:$ambariPassword "$ambariURL/api/v1/clusters/$clusterName/services?fields=ServiceInfo/service_name&ServiceInfo/maintenance_state=OFF" | python -mjson.tool | perl -ne '/"service_name":.*?"(.*?)"/ && print "$1\n"'`

else
	IFS=","
        aliveServices=($serviceCheck)
	unset IFS
fi


#Prepare curl request input

postBody=
for service in ${aliveServices[@]};
do
userChoice="Y"
	if [ "$service" == "ZOOKEEPER" ]; then
        	postBody="{\"RequestInfo\":{\"context\":\"$service Service Check\",\"command\":\"${service}_QUORUM_SERVICE_CHECK\"},\"Requests/resource_filters\":[{\"service_name\":\"$service\"}]}"

	elif [ "$service" == "KERBEROS" ]; then
        	existingCredentials=`curl $sslFlag -s -u $ambariUser:$ambariPassword -H "X-Requested-By:X-Requested-By" -X GET  "$ambariURL/api/v1/clusters/$clusterName/credentials/kdc.admin.credential" | python -mjson.tool | grep status`
		if [ ! -z "$existingCredentials" ]; then
        		echo "KERBEROS service check requires KDC admin principal and password."
			read -p "Press 'y' to perform KERBEROS service check, To skip, press 'n'   : " userChoice
			if [  "$userChoice" == "y" -o  "$userChoice" == "Y" ] ; then
				read -p "Enter Kerberos Admin Principal:" princ
        			read -sp "Enter Kerberos Admin password:" krbpwd
        			kerberosPost="{\"Credential\" : { \"principal\" : \"$princ\", \"key\" : \"$krbpwd\", \"type\" : \"temporary\"} }"
        			curl $sslFlag -s -u $ambariUser:$ambariPassword -H "X-Requested-By:X-Requested-By" -X POST --data "$kerberosPost"  "$ambariURL/api/v1/clusters/$clusterName/credentials/kdc.admin.credential"
			fi
        fi

	    postBody="{\"RequestInfo\":{\"context\":\"$service Service Check\",\"command\":\"${service}_SERVICE_CHECK\"},\"Requests/resource_filters\":[{\"service_name\":\"$service\"}]}"

		if [ "$userChoice" == "Y" -o "$userChoice" == "y" ] ; then
			 echo "\nInitiating service check for $service\n"
    			curl $sslFlag -s -u $ambariUser:$ambariPassword -H "X-Requested-By:X-Requested-By" -X POST --data "$postBody"  "$ambariURL/api/v1/clusters/$clusterName/requests"
		fi
	else
        	postBody="{\"RequestInfo\":{\"context\":\"$service Service Check\",\"command\":\"${service}_SERVICE_CHECK\"},\"Requests/resource_filters\":[{\"service_name\":\"$service\"}]}"
    	fi

    if [ "$service" != "KERBEROS" ] ; then
    	echo "Initiating service check for $service"
    	curl $sslFlag -s -u $ambariUser:$ambariPassword -H "X-Requested-By:X-Requested-By" -X POST --data "$postBody"  "$ambariURL/api/v1/clusters/$clusterName/requests"
    fi

done;
