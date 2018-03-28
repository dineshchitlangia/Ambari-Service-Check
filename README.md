# scripts
## ambari-service-check.sh

This script triggers service checks for components which are not in maintenance mode.
Once service checks are triggered, you can monitor their progress from Ambari UI.

It can be used with following arguments:
* -u \<ambariAdminUser> 
* -p \<ambariAdminPassword> 
* -s <all|comma-separated list> 

Optional arguments:
* \[-t \<ambariServerHost or IP Address>] 
* \[-n \<ambariServerPort>] 
* \[-c \<empty or path to cert file>] to be used when Ambari SSL is enabled

When using -c 
* Mention -c at the end of the command as shown in the examples
* Mention the path to the CAcerts file (preferably) or the Ambari certs file (if selfsigned) to trust the https connectivity to Ambari.
* If either paths are not available, you may use -c without any path.

If not specified, default value for -t : localhost

If not specified, default value for -p : 8080(when SSL disabled) and 8443(when SSL enabled)


For KERBEROS service check, script will prompt for an option to skip service check.
You may skip the check for KERBEROS if you do not have KDC Admin principal and password.

If executing this script on Ambari Server host, you do not need to specify -t and -p options

* Example: Trigger Service Check for all components

  * sh ambari-service-check.sh -u admin -p admin -s all

* Example: Trigger Service Check for only for HIVE, HDFS, and KNOX

  * sh ambari-service-check.sh -u admin -p admin -s hive,hdfs,knox

* Example: Trigger Service Check for only for HIVE, HDFS, and KNOX when ssl is enabled
  * sh ambari-service-check.sh -u admin -p admin -s hive,hdfs,knox -c

* Example: Trigger Service Check for only for HIVE, HDFS, and KNOX when ssl is enabled and you want to specify cert file
  * sh ambari-service-check.sh -u admin -p admin -s hive,hdfs,knox -c /path/to/cert/file
