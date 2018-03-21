usage() { 
echo "
This script triggers service checks for components which are not in maintenance mode
Usage: sh ambari-service-check.sh -u <user> -p <password> -s <all|comma-separated list> [-t <ambariServerHost>] [-n <ambariServerPort>] [-c <clusterName>] \n
If not specified, default value for -t : localhost
If not specified, default value for -p : 8080

Example: Trigger Service Check for all components which are not in Maintenance Mode
sh ambari-service-check.sh -u admin -p admin -s all

Example: Trigger Service Check for only for HIVE, HDFS, and KNOX
sh ambari-service-check.sh -u admin -p admin -s hive,hdfs,knox
" 1>&2; exit 1; 
}

while getopts "u:p:t::n::c::s:" opt; do
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
	c)
            clusterName=${OPTARG}
            ;;
        s)
            serviceCheck=`echo ${OPTARG} | tr [a-z] [A-Z]`
            if [ -z "$serviceCheck" ]; then
		usage
            fi
            ;;

        *)
	    echo "Invalid option specified."
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# Set Default Values

if [ -z "$ambariHost" ]; then
	ambariHost="localhost"
fi
if [ -z "$ambariPort" ]; then
	ambariPort="8080"
fi
if [ -z "$clusterName" ]; then
	clusterName=`curl -s -u $ambariUser:$ambariPassword "http://$ambariHost:$ambariPort/api/v1/clusters"  | python -mjson.tool | perl -ne '/"cluster_name":.*?"(.*?)"/ && print "$1\n"'`;
fi



#Prepare list of services for which checks should be triggered

if [ "$serviceCheck" == "ALL" ] ; then
	aliveServices=`curl -s -u $ambariUser:$ambariPassword "http://$ambariHost:$ambariPort/api/v1/clusters/$clusterName/services?fields=ServiceInfo/service_name&ServiceInfo/maintenance_state=OFF" | python -mjson.tool | perl -ne '/"service_name":.*?"(.*?)"/ && print "$1\n"'`

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
        	existingCredentials=`curl -s -u $ambariUser:$ambariPassword -H "X-Requested-By:X-Requested-By" -X GET  "http://$ambariHost:$ambariPort/api/v1/clusters/$clusterName/credentials/kdc.admin.credential" | python -mjson.tool | grep status`
		if [ ! -z "$existingCredentials" ]; then
        		echo "KERBEROS service check requires KDC admin principal and password."
			read -p "Press 'y' to perform KERBEROS service check, To skip, press 'n'   : " userChoice
			if [  "$userChoice" == "y" -o  "$userChoice" == "Y" ] ; then
				read -p "Enter Kerberos Admin Principal:" princ
        			read -sp "Enter Kerberos Admin password:" krbpwd
        			kerberosPost="{\"Credential\" : { \"principal\" : \"$princ\", \"key\" : \"$krbpwd\", \"type\" : \"temporary\"} }"
        			curl -s -u $ambariUser:$ambariPassword -H "X-Requested-By:X-Requested-By" -X POST --data "$kerberosPost"  "http://$ambariHost:$ambariPort/api/v1/clusters/$clusterName/credentials/kdc.admin.credential"
			fi
        fi
	    
	    postBody="{\"RequestInfo\":{\"context\":\"$service Service Check\",\"command\":\"${service}_SERVICE_CHECK\"},\"Requests/resource_filters\":[{\"service_name\":\"$service\"}]}"
		
		if [ "$userChoice" == "Y" -o "$userChoice" == "y" ] ; then
			 echo "\nInitiating service check for $service\n"
    			curl -s -u $ambariUser:$ambariPassword -H "X-Requested-By:X-Requested-By" -X POST --data "$postBody"  "http://$ambariHost:$ambariPort/api/v1/clusters/$clusterName/requests"
		fi
	else
        	postBody="{\"RequestInfo\":{\"context\":\"$service Service Check\",\"command\":\"${service}_SERVICE_CHECK\"},\"Requests/resource_filters\":[{\"service_name\":\"$service\"}]}"
    	fi

    if [ "$service" != "KERBEROS" ] ; then
    	echo "Initiating service check for $service"
    	curl -s -u $ambariUser:$ambariPassword -H "X-Requested-By:X-Requested-By" -X POST --data "$postBody"  "http://$ambariHost:$ambariPort/api/v1/clusters/$clusterName/requests"
    fi

done;
