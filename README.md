# Oozie_hbaseExportSnapshotBackup_HA
Oozie Workflow that captures snapshot of a Hbase table and exports to remote HA cluster using native hbase ExportSnapshot tool and clones to new table on remote cluster (https://hbase.apache.org/book.html#ops.snapshots)

### Capabilities
- Accesses both clusters with given parameters as hbase shell to create snapshot on source and clone table from exported snapshot on remote cluster
- Support secure and non-secure clusters with same or independent realms as long as Trust is enabled.
- tested on HDP 2.6 secure clusters with same realm
- Designed to run where source cluster doesn't have remote cluster HA properties using similar technique mentioned here: https://community.hortonworks.com/repos/174530/how-to-run-oozie-distcp-workflow-with-two-hdfs-ha.html

### Requirements/Inputs
- Assumes Source cluster where oozie workflow runs has HBase Client
- Assumes remote cluster is HA

### Technical Configurations needed for job.properies or coordinator.xml
All the source cluster configurations are defined with prefix that starts with "src", similarly remote ones with "dest"
Sample configurations for a test job I have used:

```
###Source Cluster Configurations
srcClusterSecurity=kerberos
srcClusterRealm=HWX.COM
srcClusterZkQuorum=c176-node4.ha264.com,c176-node3.ha264.com,c176-node2.ha264.com
srcClusterRPC=authentication
srcClusterZnode=/hbase-secure
src_dfs_internal_nameservices=ha264

###Destination Cluster Configurations
destClusterSecurity=kerberos
destClusterRealm=HWX.COM
destClusterZkQuorum=c376-node3.bbg263.com,c376-node4.bbg263.com,c376-node2.bbg263.com
destClusterRPC=authentication
destClusterZnode=/hbase-secure

dest_dfs_internal_nameservices=bbg263
dest_dfs_namenode_rpc_address_nn1=c376-node2.bbg263.com:8020
dest_dfs_namenode_rpc_address_nn2=c376-node3.bbg263.com:8020
destHbaseRootDir=/apps/hbase/data

###Table and Snapshot details.
srcSnapshotName=ha264_default.emp_ooziebackup
srcTableNameSpace=default
srcTableName=emp

destSnapshotName=ha264_default.emp_ooziebackup
destTableName=ooziebackups:ha264_default.emp_clone_ooziebackup

###Job Level Configuratons
exportMappers=4
exportBandwidth=25
```

### Example for table backup between ha264 to bbg263 cluster
With the right coordinator.xml and bundles in place as upload under examples folder, we should be able to run below command to start independent backup jobs(this ex. 5 and 15min) that runs continuously  for given table(this ex.US_POPULATION)  for given cluster pair.
```
oozie job -run -D oozie.bundle.application.path=/oozie_workflows/bundles/testfreq/bundle.xml -D srcTableName=US_POPULATION -D nameNode=hdfs://ha264 -D jobTracker=c176-node2.ha264.com:8050
```
It would then have backups such as below on source side
```
 ha264_default.US_POPULATION_ooziebackup_15                                   US_POPULATION (Thu Sep 13 23:01:37 UTC 2018)
 ha264_default.US_POPULATION_ooziebackup_5                                    US_POPULATION (Thu Sep 13 23:01:51 UTC 2018)
 ```
 and following backup clone tables such as below on remote side
 ```
ooziebackups:ha264_default.US_POPULATION_ooziebackup_15_clone
ooziebackups:ha264_default.US_POPULATION_ooziebackup_5_clone
 ```
