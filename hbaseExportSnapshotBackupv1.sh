echo hbaseExportSnapshotBackup.sh Script Started

dfs_internal_nameservices="$(hdfs getconf -confKey dfs.nameservices),${dest_dfs_internal_nameservices}"
echo srcClusterSecurity=${srcClusterSecurity}
echo srcClusterRealm=${srcClusterRealm}
echo srcClusterZkQuorum=${srcClusterZkQuorum}
echo srcClusterRPC=${srcClusterRPC}
echo srcClusterZnode=${srcClusterZnode}
echo destClusterSecurity=${destClusterSecurity}
echo destClusterRealm=${destClusterRealm}
echo destClusterZkQuorum=${destClusterZkQuorum}
echo destClusterRPC=${destClusterRPC}
echo destClusterZnode=${destClusterZnode}

echo dfs_internal_nameservices=${dfs_internal_nameservices}
echo dest_dfs_internal_nameservices=${dest_dfs_internal_nameservices}
echo dest_dfs_namenode_rpc_address_nn1=${dest_dfs_namenode_rpc_address_nn1}
echo dest_dfs_namenode_rpc_address_nn2=${dest_dfs_namenode_rpc_address_nn2}
echo srcSnapshotName=${srcSnapshotName}
echo srcTableName=${srcTableName}
echo exportMappers=${exportMappers}
echo destHbaseRootDir=${destHbaseRootDir}
echo destSnapshotName=${destSnapshotName}
echo destTableName=${destTableName}

mkdir src
echo -e "<configuration>
<property><name>hadoop.security.authentication</name><value>${srcClusterSecurity}</value></property>
<property><name>hbase.security.authentication</name><value>${srcClusterSecurity}</value></property>
<property><name>hbase.master.kerberos.principal</name><value>hbase/_HOST@${srcClusterRealm}</value></property>
<property><name>hbase.regionserver.kerberos.principal</name><value>hbase/_HOST@${srcClusterRealm}</value></property>
<property><name>hbase.zookeeper.quorum</name><value>${srcClusterZkQuorum}</value></property>
<property><name>hadoop.rpc.protection</name><value>${srcClusterRPC}</value></property>
<property><name>hbase.rpc.protection</name><value>${srcClusterRPC}</value></property>
<property><name>zookeeper.znode.parent</name><value>${srcClusterZnode}</value></property>
</configuration>" > src/hbase-site.xml

mkdir dest
echo -e "
<configuration>
<property><name>hadoop.security.authentication</name><value>${destClusterSecurity}</value></property>
<property><name>hbase.security.authentication</name><value>${destClusterSecurity}</value></property>
<property><name>hbase.master.kerberos.principal</name><value>hbase/_HOST@${destClusterRealm}</value></property>
<property><name>hbase.regionserver.kerberos.principal</name><value>hbase/_HOST@${destClusterRealm}</value></property>
<property><name>hbase.zookeeper.quorum</name><value>${destClusterZkQuorum}</value></property>
<property><name>hadoop.rpc.protection</name><value>${destClusterRPC}</value></property>
<property><name>hbase.rpc.protection</name><value>${destClusterRPC}</value></property>
<property><name>zookeeper.znode.parent</name><value>${destClusterZnode}</value></property>
</configuration>" > dest/hbase-site.xml

cat src/hbase-site.xml
cat dest/hbase-site.xml

dfs_internal_nameservices="$(hdfs getconf -confKey dfs.nameservices),${dest_dfs_internal_nameservices}"


#########SRC SIDE HBASE SHELL
#########SRC SIDE HBASE SHELL
echo -e "srcSnapshotName= ENV['srcSnapshotName']
srcTableName = ENV['srcTableName']
puts \"entered src hbase cluster shell\"
puts \"Got these values from environment: srcTableName=\" + srcTableName + \" srcTableName=\" + srcTableName
puts \"Checking if snapshot : \" + srcSnapshotName+ \" already exists. Will delete if it exists\"
if !list_snapshots(srcSnapshotName).empty?
  delete_snapshot srcSnapshotName
end
puts \"Creating snapshot : \" + srcSnapshotName + \" on table : \" + srcTableName
snapshot \"#{srcTableName}\", srcSnapshotName
list_snapshots(srcSnapshotName)
" | hbase --config src shell -n

[ $? -ne 0 ] && echo Previous Hbase shell failed, error code $? && exit 1


#########SRC SIDE HBASE exportSnapshot hadoop job
export HADOOP_CLASSPATH=`hbase classpath`
hbaseexportcmd="hadoop jar /usr/hdp/current/hbase-client/lib/hbase-server.jar exportsnapshot \
-Ddfs.nameservices=${dfs_internal_nameservices} \
-Ddfs.client.failover.proxy.provider.${dest_dfs_internal_nameservices}=org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider \
-Ddfs.ha.namenodes.${dest_dfs_internal_nameservices}=nn1,nn2 \
-Ddfs.namenode.rpc-address.${dest_dfs_internal_nameservices}.nn1=${dest_dfs_namenode_rpc_address_nn1} \
-Ddfs.namenode.rpc-address.${dest_dfs_internal_nameservices}.nn2=${dest_dfs_namenode_rpc_address_nn2} -Dmapreduce.job.send-token-conf='mapreduce.jobhistory.principal|^dfs.nameservices|^dfs.namenode.rpc-address.*|^dfs.ha.namenodes.*|^dfs.client.failover.proxy.provider.*|dfs.namenode.kerberos.principal' -snapshot ${srcSnapshotName} -copy-to hdfs://${dest_dfs_internal_nameservices}${destHbaseRootDir} "

echo $hbaseexportcmd
eval $hbaseexportcmd

[ $? -ne 0 ] && echo "Previous Hbase Export failed, error code $?" && exit 1


#########DEST SIDE HBASE SHELL
echo -e "destSnapshotName = ENV['destSnapshotName']
destTableName = ENV['destTableName']
puts \"entered dest hbase cluster shell to clone a new table\"
puts \"Got these values from environment: destSnapshotName=\" + destSnapshotName + \" destTableName=\" + destTableName
puts \"Checking if snapshot was created: \" + destSnapshotName

if !list_snapshots(destSnapshotName).empty?
puts 'Snapshot exists : ' +  destSnapshotName
puts \"Checking if clone table already exists: \" + destTableName + \" If it does will drop it since we have latest snapshot.\"
	if !list(destTableName).empty?
		puts \"Clone table exists, will drop table :\" + destTableName
		disable destTableName
		drop destTableName
	end
	puts \"Cloning Snapshot : \"  + ' with destination clone table as : ' + destTableName
	clone_snapshot destSnapshotName, destTableName

	if !list(destTableName).empty?
	puts \"Verified table :\" + destTableName + \" So will delete snapshot: \" + destSnapshotName
		delete_snapshot destSnapshotName
	else    puts \"Didn't find destination table. will not delete snapshot \"
		
	end
end
" | hbase --config dest shell -n
