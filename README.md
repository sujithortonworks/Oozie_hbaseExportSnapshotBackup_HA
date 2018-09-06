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
All the source cluster configurations are defined with prefix that starts with "src", similarly remote ones with "dest
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
srcTableName=default:emp

destSnapshotName=ha264_default.emp_ooziebackup
destTableName=ooziebackups:ha264_default.emp_clone_ooziebackup

###Job Level Configuratons
exportMappers=4
exportBandwidth=25
```
