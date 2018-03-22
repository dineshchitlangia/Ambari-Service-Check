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
* \[-c \<clusterName>]
  
If not specified, default value for -t : localhost

If not specified, default value for -p : 8080

For KERBEROS service check, script will prompt for an option to skip service check.
You may skip the check for KERBEROS if you do not have KDC Admin principal and password.

If executing this script on Ambari Server host, you do not need to specify -t and -p options

* Example: Trigger Service Check for all components

  * sh ambari-service-check.sh -u admin -p admin -s all

* Example: Trigger Service Check for only for HIVE, HDFS, and KNOX

  * sh ambari-service-check.sh -u admin -p admin -s hive,hdfs,knox


