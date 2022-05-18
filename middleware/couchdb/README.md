### 每个节点确保已启用集群
curl -X POST -H "Content-Type: application/json" http://admin:denglu0416@127.0.0.1:5984/_cluster_setup -d '{"action": "enable_cluster", "bind_address":"0.0.0.0", "username": "admin", "password":"denglu0416", "node_count":"3"}'

### 添加节点
#### 添加节点1
curl -X POST -H "Content-Type: application/json" http://admin:denglu@127.0.0.1:5984/_cluster_setup -d '{"action": "enable_cluster", "bind_address":"0.0.0.0", "username": "admin", "password":"denglu0416", "port": 5984, "node_count": "3", "remote_node": "couchdb-1.couchdb-hs.common-middleware.svc>", "remote_current_user": "admin", "remote_current_password": "password" }'
curl -X POST -H "Content-Type: application/json" http://admin:denglu0416@127.0.0.1:5984/_cluster_setup -d '{"action": "add_node", "host":"couchdb-1.couchdb-hs.common-middleware.svc", "port": 5984, "username": "admin", "password":"denglu0416"}'

##### 添加节点2
curl -X POST -H "Content-Type: application/json" http://admin:denglu@127.0.0.1:5984/_cluster_setup -d '{"action": "enable_cluster", "bind_address":"0.0.0.0", "username": "admin", "password":"denglu0416", "port": 5984, "node_count": "3", "remote_node": "couchdb-2.couchdb-hs.common-middleware.svc>", "remote_current_user": "admin", "remote_current_password": "password" }'
curl -X POST -H "Content-Type: application/json" http://admin:denglu0416@127.0.0.1:5984/_cluster_setup -d '{"action": "add_node", "host":"couchdb-2.couchdb-hs.common-middleware.svc", "port": 5984, "username": "admin", "password":"denglu0416"}'

#### 完成配置集群
curl -X POST -H "Content-Type: application/json" http://admin:denglu0416@127.0.0.1:5984/_cluster_setup -d '{"action": "finish_cluster"}'

### 查看集群成员
curl http://admin:denglu0416@127.0.0.1:5984/_membership

### 通过web查看
http://10.10.5.8:30984/_utils




