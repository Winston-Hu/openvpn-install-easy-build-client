# EC2 OpenVPN 安装配置说明

本文档整理了本次在 AWS EC2 上使用 `openvpn-install.sh` 进行交互式安装时的选择，并解释每个选项的含义。

## 环境信息

- 操作系统：Ubuntu 24.04.4 LTS
- 内核：`6.17.0-1007-aws`
- 公网 IP：`13.237.209.198`
- 私网 IP：`172.31.7.73`
- Init 系统：`systemd 255`
- TUN 设备：已存在 `/dev/net/tun`

说明：
- `13.237.209.198` 是公网 IP，OpenVPN 客户端应连接这个地址。
- `172.31.7.73` 是 AWS VPC 内网地址，只用于云内通信，不应用作客户端入口地址。

## 本次安装选择

### 1. 客户端连接到服务器所用的 IP 版本

- 选择：`IPv4`

含义：
- 客户端通过服务器的公网 IPv4 地址连接 OpenVPN。
- 当前服务器未检测到可用 IPv6，因此这是正确选择。

实际填写：

```text
Endpoint type [1-2]: 1
Server listening IPv4 address: 13.237.209.198
```

### 2. VPN 客户端使用的 IP 版本

- 选择：`IPv4 only`

含义：
- VPN 内只分配 IPv4 地址。
- 客户端通过 VPN 走 IPv4 出口访问互联网。
- 不启用 IPv6 隧道，也避免额外的 IPv6 路由和 DNS 配置复杂度。

实际填写：

```text
Client IP versions [1-3]: 1
```

### 3. VPN IPv4 子网

- 选择：自定义 `10.188.0.0/24`

含义：
- OpenVPN 服务器会给客户端分配 `10.188.0.x` 网段中的地址。
- 这与当前 AWS 私网 `172.31.0.0/16` 不冲突。

注意：
- 该网段最好也不要和你本地家庭/办公室网络冲突。
- 如果本地网络刚好也使用 `10.188.0.0/24`，后续可能出现路由问题。

实际填写：

```text
IPv4 subnet choice [1-2]: 2
Custom IPv4 subnet: 10.188.0.0
```

### 4. OpenVPN 监听端口

- 选择：默认 `1194`

含义：
- OpenVPN 服务监听标准默认端口 `1194`。
- 配合后续 `UDP` 协议，实际需要放行的是 `UDP 1194`。

实际填写：

```text
Port choice [1-3]: 1
```

### 5. OpenVPN 传输协议

- 选择：`UDP`

含义：
- UDP 是 OpenVPN 的常见默认选择，性能通常优于 TCP。
- 除非处于某些只允许 TCP 出站的受限网络，否则优先使用 UDP。

实际填写：

```text
Protocol [1-2]: 1
```

### 6. VPN 下发给客户端的 DNS

- 选择：`Cloudflare`

含义：
- 客户端连接 VPN 后会优先使用 Cloudflare DNS。
- 默认会下发：
  - `1.1.1.1`
  - `1.0.0.1`

优点：
- 配置简单
- 解析速度通常较好
- 适合作为默认公共 DNS

实际填写：

```text
DNS [1-13]: 3
```

### 7. 是否允许一个 `.ovpn` 配置同时给多个设备使用

- 选择：`n`

含义：
- 一个客户端配置文件只对应一个设备。
- 更适合正式使用和后续管理。

优点：
- 每台设备一个独立证书
- 某个设备丢失时可以单独吊销
- 管理和审计更清晰

实际填写：

```text
Allow multiple devices per client? [y/n]: n
```

### 8. 是否自定义隧道 MTU

- 选择：默认 `1500`

含义：
- MTU 保持默认值，适合大多数网络环境。
- 只有在后续遇到特殊网络兼容性问题时，才通常需要调小到 `1400` 一类的值。

实际填写：

```text
MTU choice [1-2]: 1
```

### 9. 认证模式

- 选择：`PKI (Certificate Authority)`

含义：
- 使用传统 CA 证书体系签发服务端和客户端证书。
- 这是 OpenVPN 最成熟、最常见的部署模式。

优点：
- 兼容性最好
- 适合后续新增客户端
- 支持单独吊销某个客户端证书
- 后续续期和维护路径更成熟

实际填写：

```text
Authentication mode [1-2]: 1
```

### 10. 是否自定义加密参数

- 选择：`n`

含义：
- 使用脚本提供的默认安全参数。
- 对当前场景来说，这是最稳妥的选择。

说明：
- 该脚本的默认配置已经比 OpenVPN 历史默认值更现代、更安全。
- 在没有明确兼容性或性能目标前，不建议手工修改。

实际填写：

```text
Customize encryption settings? [y/n]: n
```

## 这套配置最终意味着什么

按当前选择，最终会得到一台：

- 通过公网 IPv4 `13.237.209.198` 提供服务的 OpenVPN 服务器
- 使用 `UDP/1194`
- 给客户端分配 `10.188.0.0/24` 网段地址
- 客户端只走 IPv4 VPN
- 使用 Cloudflare DNS
- 每个客户端配置文件对应一个设备
- 使用传统 CA/证书体系管理客户端

## AWS 侧需要确认的事项

至少确认安全组已放行：

- `TCP 22`：用于 SSH
- `UDP 1194`：用于 OpenVPN

如果 `UDP 1194` 未放行，即使服务安装成功，客户端也无法连接。

## 下一步

在安装脚本继续执行并完成后，通常还需要：

1. 生成第一个客户端配置文件
2. 找到生成的 `.ovpn` 文件
3. 将 `.ovpn` 从服务器复制回本地电脑
4. 在本地 OpenVPN 客户端中导入该文件并连接

如果后续需要，可以在本仓库中继续补充：

- 客户端文件导出步骤
- AWS 安全组配置截图说明
- 常见故障排查记录

## 运行方式

下面整理两种常见运行方式。

### 方式一：在仓库目录中运行

适用于：
- 需要保留仓库源码
- 后续还要查看 README、FAQ、脚本历史
- 计划继续在服务器上维护该仓库

命令如下：

```bash
cd ~/githubrepos
git clone https://github.com/angristan/openvpn-install.git
cd ~/githubrepos/openvpn-install
chmod +x openvpn-install.sh
sudo ./openvpn-install.sh interactive
```

如果后续要继续创建和管理 client，请参考：

- [EC2_OpenVPN_Client_Notes.md](/Users/jdk/github_repos/openvpn-install/EC2_OpenVPN_Client_Notes.md)

### 方式二：直接下载单个 `sh` 脚本运行

适用于：
- 只想快速安装
- 不需要在服务器上保留完整仓库

命令如下：

```bash
cd ~
curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
chmod +x openvpn-install.sh
sudo ./openvpn-install.sh interactive
```

如果只下载了单个脚本而没有保留仓库，后续新增 client 仍然建议保留一份辅助脚本，或直接在服务器上按同样逻辑手工生成。

## Client 管理文档

Client 的创建、固定 IP、`ccd`、`iroute`、导出 `.ovpn` 等内容已拆分到独立文档：

- [EC2_OpenVPN_Client_Notes.md](/Users/jdk/github_repos/openvpn-install/EC2_OpenVPN_Client_Notes.md)
