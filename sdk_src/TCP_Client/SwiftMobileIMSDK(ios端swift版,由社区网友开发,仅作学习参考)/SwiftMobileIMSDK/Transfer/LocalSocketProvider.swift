//
//  LocalSocketProvider.swift
//  SwiftMobileIMSDK
//
//  Created by fishbay on 2021/8/8.

//  本地 TCP Socket 实例封装实用类

import UIKit

class LocalSocketProvider: NSObject, GCDAsyncSocketDelegate {
    /// header tag
    static let TCP_TAG_FIXED_LENGTH_HEADER: Int = 990
    /// body tag
    static let TCP_TAG_RESPONSE_BODY: Int = 991
    
    /// 本地socket对象
    var localSocket: GCDAsyncSocket?
    
    /// socket连接完成后的回调，此回调一旦设置后只会被调用一次，都将在调用完成后被置nil
    var connectionCompletionOnce: ConnectionCompletion?
    
    /// 单例
    private static let instance = LocalSocketProvider()
    static func sharedInstance() -> LocalSocketProvider {
        return instance
    }
    override private init() {
        CAPrint("LocalSocketProvider已经init了")
    }
    
    /// 重置socket
    func resetLocalSocket() -> GCDAsyncSocket {
        self.closeLocalSocket()
        
        if ClientCoreSDK.isEnableDebug() {
            CAPrint("【IMCORE-TCP】new GCDAsyncSocket中...")
        }
        
        self.localSocket = GCDAsyncSocket.init(delegate: self, delegateQueue: DispatchQueue.main)
        
        return self.localSocket!
    }
    
    /// 重新连接到服务器
    /// - Parameters:
    ///   - socket: socket对象
    ///   - finish: 回调
    /// - Returns: 连接到状态值
    func tryConnectToHost(socket: GCDAsyncSocket, finish: ConnectionCompletion?) -> ErrorCode {
        if ConfigEntity.getServerIP() == nil {
            if ClientCoreSDK.isEnableDebug() {
                CAPrint("【IMCORE-TCP】tryConnectToHost 无法连接到目标主机\(ConfigEntity.getServerIP() ?? ""):\(ConfigEntity.getServerPort() ?? 0)，因为服务器ip是null")
            }
            
            return .serverNetworkNotSetup
        }
        
        /// 设置连接结果回调
        if finish != nil {
            self.setConnectionCompletionOnce(connectionCompletionOnce: finish!)
        }
        
        do {
            try socket.connect(toHost: ConfigEntity.getServerIP() ?? "", onPort: UInt16(ConfigEntity.getServerPort() ?? 0))
            
            if ClientCoreSDK.isEnableDebug() {
                CAPrint("【IMCORE-TCP】localTCPSocket尝试发出连接到目标主机\(ConfigEntity.getServerIP() ?? ""):\(ConfigEntity.getServerPort() ?? 0)的动作成功了")
            }
            
            return .commonCodeOK
        } catch {
            if ClientCoreSDK.isEnableDebug() {
                CAPrint("IMCORE-TCP】localTCPSocket尝试发出连接到目标主机\(ConfigEntity.getServerIP() ?? ""):\(ConfigEntity.getServerPort() ?? 0)的动作时出错了:\(error)")
            }
            
            return .badDisconnectToServer
        }
    }
    
    /// socket是否连接正常
    /// - Returns: true-连接，false-未连接
    func isLocalSocketReady() -> Bool {
        return self.localSocket != nil && self.localSocket!.isConnected
    }
    
    /// 获取socket对象
    /// - Returns: socket对象
    func getLocalSocket() -> GCDAsyncSocket {
        if isLocalSocketReady() {
            if ClientCoreSDK.isEnableDebug() {
                CAPrint("【IMCORE-TCP】isLocalSocketReady()==true，直接返回本地socket引用哦")
            }
            
            return self.localSocket!
        } else {
            if ClientCoreSDK.isEnableDebug() {
                CAPrint("【IMCORE-TCP】isLocalSocketReady()==false，需要先resetLocalUDPSocket()...")
            }
            
            return resetLocalSocket()
        }
    }
    
    /// 关闭socket
    func closeLocalSocket() {
        if ClientCoreSDK.isEnableDebug() {
            CAPrint("【IMCORE-TCP】正在closeLocalSocket()...")
        }
        
        if self.localSocket == nil {
            CAPrint("【IMCORE-TCP】Socket处于未初化状态（可能是您还未登陆），无需关闭。")
            return
        }
        
        self.localSocket!.disconnect()
        self.localSocket = nil
    }
    
    /// 设置回调
    /// - Parameter connectionCompletionOnce: 回调参数
    func setConnectionCompletionOnce(connectionCompletionOnce: @escaping ConnectionCompletion) {
        self.connectionCompletionOnce = connectionCompletionOnce
    }
    
    // MARK: - GCDAsyncSocketDelegate代码实现
    
    /// 当socket成功写入数据到发送缓冲区后，将调用此方法
    /// - Parameters:
    ///   - sock: socket对象
    ///   - tag: 标志
    public func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        if ClientCoreSDK.isEnableDebug() {
            CAPrint("【IMCORE-TCP-SOCKET】tag为\(tag)的数据已成功Write完成")
        }
    }
    
    /// 当socket成功读取数据到接收缓冲区后，将调用此方法
    /// - Parameters:
    ///   - sock: socket对象
    ///   - didRead: 接收到的数据
    ///   - tag: 标志
    public func socket(_ sock: GCDAsyncSocket, didRead: Data, withTag tag:Int) {
        if ClientCoreSDK.isEnableDebug() {
            CAPrint("【IMCORE-TCP-SOCKET】RECV【原始帧】：\(didRead)")
        }
        
        // 读取到的是TCP帧的Header数据
        if tag == Self.TCP_TAG_FIXED_LENGTH_HEADER {
            // 从帧的Header中解码出本次要传输的数据Body长度
            let bodyLength = TCPFrameCodec.decodeBodyLength(headerData: didRead)
            let maxLength = TCPFrameCodec.getTcpFrameMaxBodyLength()
            
            // 解码出的Body长度不合法
            if bodyLength <= 0 || bodyLength > maxLength {
                if ClientCoreSDK.isEnableDebug() {
                    CAPrint("【IMCORE-TCP-SOCKET】【CAUTION】【原始帧-头】中实际解析出的bodyLength=\(bodyLength) (而SDK中最大允许长度为>0 && <= \(maxLength)，它是不合法的，将断开本次scoket连接！")
                }
                
                sock.disconnect()
            } else {
                if ClientCoreSDK.isEnableDebug() {
                    CAPrint("【IMCORE-TCP-SOCKET】已正常从【原始帧-头】中解码出bodyLength=\(bodyLength)，马上开始正式读取Body数据")
                }
                
                // 正式开始读取本TCP帧的Body数据
                sock.readData(toLength: UInt(bodyLength), withTimeout: -1, tag: Self.TCP_TAG_RESPONSE_BODY)
            }
        } else if tag == Self.TCP_TAG_RESPONSE_BODY {
            if ClientCoreSDK.isEnableDebug() {
                let message = String(data: didRead, encoding: .utf8)
                CAPrint("【IMCORE-TCP-SOCKET】已正常从【原始帧-体】中解码出msg=\(message ?? "")")
            }
            
            // 进入原始协议处理
            LocalDataReceiver.sharedInstance().handleProtocol(data: didRead)
            
            // 继续读取下一个TCP帧（当然是先读取下一个帧的头啦）
            sock.readData(toLength: UInt(TCPFrameCodec.getTcpFrameFixedHeaderLength()), withTimeout: -1, tag: Self.TCP_TAG_FIXED_LENGTH_HEADER)
        } else {
            if ClientCoreSDK.isEnableDebug() {
                CAPrint("【IMCORE-TCP-SOCKET】RECV: 未知的socket:didReadData tag=\(tag)，它是不合法的，将断开本次scoket连接")
            }
            
            // 主动关闭连接（提示：连接断开后GCDAsyncSocket会主动调用“socketDidDisconnect:”哦）
            sock.disconnect()
        }
    }
    
    /// 当socket已经完整连接并准备好读和写数据时，将调用此方法
    /// - Parameters:
    ///   - sock: socket对象
    ///   - host: 主机
    ///   - port: 端口
    public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port p:UInt16) {
        if ClientCoreSDK.isEnableDebug() {
            CAPrint("【IMCORE-TCP-SOCKET】成收到的了TCP的connect反馈, isConnected ? \(sock.isConnected)")
        }
        
        // TODO: 消息的应用层处理建议放到多线程中处理，提升性能?
        // 连接结果回调
        self.connectionCompletionOnce?(true)
        
        // 连接成功建立后，立即开始第一个package头的读取
        sock.readData(toLength: UInt(TCPFrameCodec.getTcpFrameFixedHeaderLength()), withTimeout: -1, tag: Self.TCP_TAG_FIXED_LENGTH_HEADER)
    }
    
    /// 当socket连接断开时，将调用此方法
    /// - Parameters:
    ///   - socket: socket对象
    ///   - error: 错误对象
    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        if ClientCoreSDK.isEnableDebug() {
            CAPrint("【IMCORE-TCP-SOCKET】连接已断开%@，socket.isConnected?\(sock.isConnected)，ClientCoreSDK.connectedToServer?\(ClientCoreSDK.sharedInstance().connectedToServer)，error=\(String(describing: err))")
        }
        
        if ClientCoreSDK.sharedInstance().connectedToServer {
            if ClientCoreSDK.isEnableDebug() {
                CAPrint("【IMCORE-TCP-SOCKET】连接已断开，立即提前进入框架的“通信通道”断开处理逻辑(而不是等心跳线程探测到，那就已经比较迟了)")
            }
            
            // 进入框架的“通信通道”断开处理逻辑
            KeepAliveDaemon.sharedInstance().notifyConnectionLost()
        }
    }
    
}
