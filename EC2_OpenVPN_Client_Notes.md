# EC2 OpenVPN Client Notes

本文档整理当前 EC2 OpenVPN 环境中，如何创建、管理和导出 client 配置。

## 关键路径

当前环境中，client 相关文件主要位于以下位置：

- Easy-RSA 工作目录：
  [`/etc/openvpn/server/easy-rsa/`](/etc/openvpn/server/easy-rsa/)
- CA 证书：
  [`/etc/openvpn/server/easy-rsa/pki/ca.crt`](/etc/openvpn/server/easy-rsa/pki/ca.crt)
- Client 证书目录：
  [`/etc/openvpn/server/easy-rsa/pki/issued/`](/etc/openvpn/server/easy-rsa/pki/issued/)
- Client 私钥目录：
  [`/etc/openvpn/server/easy-rsa/pki/private/`](/etc/openvpn/server/easy-rsa/pki/private/)
- Client 请求文件目录：
  [`/etc/openvpn/server/easy-rsa/pki/reqs/`](/etc/openvpn/server/easy-rsa/pki/reqs/)
- OpenVPN client 模板：
  [`/etc/openvpn/server/client-template.txt`](/etc/openvpn/server/client-template.txt)
- CCD 目录：
  [`/etc/openvpn/server/ccd/`](/etc/openvpn/server/ccd/)
- 服务端主配置：
  [`/etc/openvpn/server/server.conf`](/etc/openvpn/server/server.conf)
- 手工生成的 client `.ovpn` 输出目录：
  [`/home/ubuntu/clientovpns/`](/home/ubuntu/clientovpns/)

以 `Winston_home_pi4` 为例：

- Client 证书：
  [`/etc/openvpn/server/easy-rsa/pki/issued/Winston_home_pi4.crt`](/etc/openvpn/server/easy-rsa/pki/issued/Winston_home_pi4.crt)
- Client 私钥：
  [`/etc/openvpn/server/easy-rsa/pki/private/Winston_home_pi4.key`](/etc/openvpn/server/easy-rsa/pki/private/Winston_home_pi4.key)
- CCD 文件：
  [`/etc/openvpn/server/ccd/Winston_home_pi4`](/etc/openvpn/server/ccd/Winston_home_pi4)
- 导出的 `.ovpn`：
  [`/home/ubuntu/clientovpns/Winston_home_pi4.ovpn`](/home/ubuntu/clientovpns/Winston_home_pi4.ovpn)

## Client 创建方式

当前推荐的 client 创建方式，是使用仓库根目录下的辅助脚本：

- [manual-client-ovpn.sh](/Users/jdk/github_repos/openvpn-install/manual-client-ovpn.sh)

这套方式已经过实际测试，生成的 `.ovpn` 可成功连接。

它会完成这些工作：
- 生成新的 client 证书和私钥
- 基于 `/etc/openvpn/server/client-template.txt` 拼装完整 `.ovpn`
- 默认把 `.ovpn` 保存到 `/home/ubuntu/clientovpns/`
- 如果指定 `--ifconfig-push`，自动写入 `/etc/openvpn/server/ccd/<client>`
- 如果指定 `--iroute`，也会一并写入该 `ccd` 文件

## 已验证成功的示例

本次已成功创建并测试：

- 客户端名称：`Winston_home_pi4`
- 固定 VPN IP：`10.188.0.11`
- 输出文件：`/home/ubuntu/clientovpns/Winston_home_pi4.ovpn`

实际命令：

```bash
cd ~/githubrepos/openvpn-install
sudo ./manual-client-ovpn.sh \
  --client Winston_home_pi4 \
  --ifconfig-push 10.188.0.11
```

对应输出：

```text
[INFO] Generating client certificate for Winston_home_pi4
...
[INFO] Writing /home/ubuntu/clientovpns/Winston_home_pi4.ovpn
[INFO] Writing CCD file /etc/openvpn/server/ccd/Winston_home_pi4
[INFO] Done
Client: Winston_home_pi4
Profile: /home/ubuntu/clientovpns/Winston_home_pi4.ovpn
Fixed VPN IP: 10.188.0.11
No OpenVPN service restart was performed.
```

## 为什么采用这种方式

相比直接重新进入 `openvpn-install.sh interactive`：
- 更适合手工管理 client
- 更适合显式指定固定 VPN IP
- 更接近旧文档里“手工生成 client + 配 CCD”的维护方式
- 生成结果统一放到 `/home/ubuntu/clientovpns/`，更好管理

说明：
- 生成出来的 `.ovpn` 文件已经内嵌证书和密钥材料
- 这个文件本身就是敏感凭据，应妥善保存
- 新增 client 和新增 `ccd` 文件时，脚本不会自动重启 OpenVPN 服务

## 生成客户端后的常用操作

### 查看 `.ovpn` 文件

```bash
ls -l /home/ubuntu/clientovpns/*.ovpn
```

### 从本地电脑下载客户端文件

在你自己的电脑上执行：

```bash
scp -i your-key.pem ubuntu@13.237.209.198:/home/ubuntu/clientovpns/Winston_home_pi4.ovpn .
```

说明：
- `your-key.pem` 是你本地用于 SSH 登录 EC2 的私钥文件
- 这一步是在你的本地电脑执行，不是在 EC2 里执行

### 新增更多客户端

如果你后续有更多设备，需要为每个设备单独生成一个配置文件，推荐使用独立名称，例如：

```bash
sudo ./manual-client-ovpn.sh --client iphone --ifconfig-push 10.188.0.21
sudo ./manual-client-ovpn.sh --client ipad --ifconfig-push 10.188.0.22
sudo ./manual-client-ovpn.sh --client work_laptop --ifconfig-push 10.188.0.23
```

这样做的好处是：
- 每台设备一个独立证书
- 某一台设备丢失时可以单独吊销
- 后续续期或替换文件更清晰

## 手工生成 `.ovpn` 的辅助脚本

仓库根目录已添加一个辅助脚本：

- [manual-client-ovpn.sh](/Users/jdk/github_repos/openvpn-install/manual-client-ovpn.sh)

用途：
- 手工生成新的 client 证书和 `.ovpn`
- 默认输出到 `/home/ubuntu/clientovpns/`
- 可选写入 `ccd` 的 `ifconfig-push`
- 可选写入 `ccd` 的 `iroute`
- 适合作为当前环境中新增 client 的标准方式

## 基本用法

只生成一个新的客户端 `.ovpn`：

```bash
cd ~/githubrepos/openvpn-install
chmod +x manual-client-ovpn.sh
sudo ./manual-client-ovpn.sh --client Winston_home_pi4
```

输出文件默认在：

```text
/home/ubuntu/clientovpns/Winston_home_pi4.ovpn
```

## 指定固定 VPN IP

例如把 `Winston_home_pi4` 固定为 `10.188.0.20`：

```bash
cd ~/githubrepos/openvpn-install
sudo ./manual-client-ovpn.sh \
  --client Winston_home_pi4 \
  --ifconfig-push 10.188.0.20
```

这会额外写入：

```text
/etc/openvpn/server/ccd/Winston_home_pi4
```

内容类似：

```conf
ifconfig-push 10.188.0.20 255.255.255.0
```

## 指定固定 VPN IP 并配置 `iroute`

适用于客户端后面还挂了一个下游子网的情况。

例如：
- 客户端固定 VPN 地址：`10.188.0.20`
- 客户端后面的局域网：`192.168.72.0/24`

命令如下：

```bash
cd ~/githubrepos/openvpn-install
sudo ./manual-client-ovpn.sh \
  --client Winston_home_pi4 \
  --ifconfig-push 10.188.0.20 \
  --iroute 192.168.72.0 \
  --iroute-mask 255.255.255.0
```

生成的 `ccd` 内容类似：

```conf
ifconfig-push 10.188.0.20 255.255.255.0
iroute 192.168.72.0 255.255.255.0
```

说明：
- `ifconfig-push` 是给这个客户端固定 VPN 地址
- `iroute` 是告诉 OpenVPN 这个客户端后面还有一个子网

如果要让服务器或其他网络也能访问这个下游子网，通常还需要在 `/etc/openvpn/server/server.conf` 中补对应的：

```conf
route 192.168.72.0 255.255.255.0
```

## 当前 VPN 子网结构

你当前 OpenVPN 使用的是：

```text
10.188.0.0/24
```

这表示：
- 网络地址：`10.188.0.0`
- 子网掩码：`255.255.255.0`
- 可给客户端使用的地址通常为：`10.188.0.1` 到 `10.188.0.254`

推荐按设备编号规划，例如：
- `10.188.0.10` 给笔记本
- `10.188.0.20` 给树莓派
- `10.188.0.30` 给其他边缘设备

一般不要把以下地址分配给客户端：
- `10.188.0.0`
- `10.188.0.255`
