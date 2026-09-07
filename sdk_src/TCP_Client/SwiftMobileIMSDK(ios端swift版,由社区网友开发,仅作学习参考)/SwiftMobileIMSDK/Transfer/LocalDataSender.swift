//
//  LocalDataSender.swift
//  SwiftMobileIMSDK
//
//  Created by fishbay on 2021/8/8.
//  数据发送处理实用类

import Foundation

class LocalDataSender {
    
    /// 单例
    private static let instance: LocalDataSender = LocalDataSender()
    static func sharedInstance() -> LocalDataSender {
        return instance
    }
    private init() {
        CAPrint("LocalDataSender已经init了")
    }
    
    /// 发送数据前的检查
    /// - Returns: 检查结果
    func checkBeforeSend() -> ErrorCode {
        if ClientCoreSDK.sharedInstance().isInitialed() {
            return .commonCodeOK
        }
        
        return .clientSDKNotInitial
    }
    
    /// 发送数据到服务端
    /// - Parameter data: Protocal对象转成JSON后再编码成byte数组后的结果
    /// - Returns: 发送结果
    func sendData(data: Data?) -> ErrorCode {
        if data == nil {
            return .unknown
        }
        
        // socket操作前的常规检查
        let check = checkBeforeSend()
        if check != .commonCodeOK {
            return check
        }
        
        // 获得Socket实例
        let socket = LocalSocketProvider.sharedInstance().getLocalSocket()
        if socket.isConnected {
            return TCPUtils.send(socket: socket, data: data) ? .commonCodeOK : .commonDataSendFail
        } else {
            CAPrint("【IMCORE-TCP】scocket未连接，无法发送，本条将被忽略（data=\(data!)）")
            return .commonDataSendFail
        }
    }
    
    /// 放到质量保证队列
    /// - Parameter message: 消息
    func putToQos(message: Protocol?) {
        if message == nil {
            return
        }
        
        // 【【C2C或C2S模式下的QoS机制1/4步：将包加入到发送QoS队列中】】
        // 如果需要进行QoS质量保证，则把它放入质量保证队列中供处理(已在存在于列表中就不用再加了，已经存在则意味当前发送的这个是重传包哦)
        if message!.QoS && QoS4SendDaemon.sharedInstance().exist(fp: message!.fp) {
            QoS4SendDaemon.sharedInstance().put(message: message)
        }
    }
    
    /// 发送登陆信息，本方法同时会判断socket连接的建立情况（并在未连接的情况下首先尝试建立连接）
    /// - Parameter loginInfo: 登陆信息
    /// - Returns: 发送结果
    func sendLogin(loginInfo: LoginInfo?) -> ErrorCode {
        if loginInfo == nil {
            CAPrint("要发送的数据是nil")
            return .paramError
        }
        
        // 确保首先进行核心库的初始化（此方法多次调用是无害的，但必须要保证在使用IM核心库的任何实质方法前调用（初始化）1次）
        ClientCoreSDK.sharedInstance().initCore()
        
        // socket操作前的常规检查
        let code = checkBeforeSend()
        if code != .commonCodeOK {
            return code
        }
        
        // 获得UDPSocket实例
        let socket = LocalSocketProvider.sharedInstance().getLocalSocket()
        if !socket.isConnected {
            // 未连接
            let observerBlock = { (connectResult: Bool?) -> Void in
                if connectResult ?? false {
                    let result = self.sendLoginData(loginInfo: loginInfo!)
                    CAPrint("【IMCORE-TCP】发送登陆信息，结果：\(result)")
                } else {
                    CAPrint("【IMCORE-TCP】[来自GCDAsyncSocket的连接结果回调通知]socket连接失败，本次登陆信息未成功发出")
                }
            }
            
            // 调置连接回调
            LocalSocketProvider.sharedInstance().setConnectionCompletionOnce(connectionCompletionOnce: observerBlock)
            
            let code = LocalSocketProvider.sharedInstance().tryConnectToHost(socket: socket, finish: observerBlock)
            // 如果连接意图没有成功发出则返回错误码
            if code != .commonCodeOK {
                // 此种情况下的消息，将在应用层由QoS机制进行重传或不重传保证，所以此代码下无需再处理了
                return code
            } else {
                return .commonCodeOK
            }
        } else {
            // 已连接，直接发送
            return self.sendLoginData(loginInfo: loginInfo)
        }
    }
    
    private func sendLoginData(loginInfo: LoginInfo?) -> ErrorCode {
        if loginInfo == nil {
            return .unknown
        }
        
        // 登陆信息
        let data = ProtocolFactory.createLoginInfo(loginInfo: loginInfo!)
        let code = self.sendData(data: data.toBytes())
        
        // 登陆信息成功发出时就把登陆名存下来
        if code == .commonCodeOK {
            ClientCoreSDK.sharedInstance().setCurrentLoginInfo(loginInfo: loginInfo!)
        }
        
        return code
    }
    
    /// 发送注销登陆信息
    /// - Returns: 0表示数据发出成功，否则返回的是错误码
    func sendLoginout() -> ErrorCode {
        var code: ErrorCode = .commonCodeOK
        
        if ClientCoreSDK.sharedInstance().getLoginHasInit() ?? false {
            let loginUserId = ClientCoreSDK.sharedInstance().getCurrentLoginInfo()!.loginUserId
            let loginout = ProtocolFactory.createLoginOutInfo(userId: loginUserId!)
            
            code = self.sendData(data: loginout.toBytes()!)
            // 登出信息成功发出时
            if code == .commonCodeOK {
                // 发出退出登陆的消息同时也关闭心跳线程
                KeepAliveDaemon.sharedInstance().stop()
                // 重置登陆标识
                ClientCoreSDK.sharedInstance().setLoginHasInit(loginHasInit: false)
            }
        }
        
        // 释放SDK资源
        ClientCoreSDK.sharedInstance().releaseCore()
        
        return code
    }
    
    /// 发送Keep Alive心跳包
    /// - Returns: 0表示数据发出成功，否则返回的是错误码
    func sendKeepAlive() -> ErrorCode {
        let loginInfo = ClientCoreSDK.sharedInstance().getCurrentLoginInfo()
        
        if loginInfo == nil {
            CAPrint("发送心跳包失败，原因是登陆用户信息不存在")
            return .unknown
        }
        
        let userId = loginInfo!.loginUserId!
        let message: Protocol = ProtocolFactory.createKeepAlive(fromUserId: userId)
        
        return self.sendData(data: message.toBytes()!)
    }
    
    /// 通用数据发送的根方法
    /// - Parameter message: 要发送的内容
    /// - Returns: 0表示数据发出成功，否则返回的是错误码
    func sendCommonData(message: Protocol?) -> ErrorCode? {
        if message == nil {
            return .paramError
        }
        
        // 数据发送代码需要同步约束，否则在IM框架中此方法的相关处理涉及全局变量的设置时会出现同步操作问题
        objc_sync_enter(self)
        
        var code: ErrorCode
        
        code = self.sendData(data: message!.toBytes())
        if code == .commonCodeOK {
            self.putToQos(message: message)
        } else {
            code = .commonInvalidProtocol
        }
        
        objc_sync_exit(self)
        
        return code
    }
    
    
}
