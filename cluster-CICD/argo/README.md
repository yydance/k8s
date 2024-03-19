argocd部署说明
---

### 部署，参考[官方](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
注意事项：
- 查阅官网版本对k8s版本的支持，版本不同，可能因为k8s api不同导致部署失败
- 默认rbac策略作用在`argocd`命名空间，如果部署在其他命名空间，需要修改对应的rbac策略，建议部署在`argocd`
- 如果argocd ui前端有反代，则需要在反代层增加websocket支持，argocd exec权限下的terminal终端使用websocket
- TLS配置，参考[这里](https://argo-cd.readthedocs.io/en/stable/operator-manual/tls/)
```
kubectl create secret tls argocd-server-tls --cert=./eeo.cn.pem --key=./eeo.cn.key -n argocd
```

### 集成sso
单点登录，官方组件是dex，这里使用keycloak，见[官方配置](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/keycloak/)。

修改配置configmap `argocd-cm`
```
oidc.config: |
    name: Keycloak
    issuer: https://keycloak.eeo.cn/realms/Ldap-test
    clientID: apisix-dev
    clientSecret: KR6oKLIiFJSo9ChGUdtRsi69YWuJIWM5
    requestedScopes: ["openid", "profile", "email", "groups"]
  oidc.tls.insecure.skip.verify: "true"
  url: https://argo.eeo.cn
```

RBAC权限调整
```
policy.csv: |
    g, sre, role:admin
    g, devBase, role:readonly
  policy.default: role:none
```

需要注意：keycloak配置`realm`时，配置SSL为`无`
