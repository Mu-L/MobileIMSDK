//
//  QoS4ReceiveDaemon.swift
//  SwiftMobileIMSDK
//
//  Created by fishbay on 2021/8/8.

//  QoS机制中提供对已收到包进行有限生命周期存储并提供重复性判断的守护线程

import Foundation

class QoS4ReceiveDaemon {
    
    /// 检查线程执行间隔（单位：毫秒），默认5分钟
    static var checkInterval: Int = 5 * 60 * 1000
    /// 一个消息放到在列表中（用于判定重复时使用）的生存时长（单位：毫秒），默认10分钟
    static var messageValidTime = 10 * 60 * 1000
    
    /// 时间间隔内接收到的需要QoS质量保证的消息指纹特征列表，key=消息包指纹码，value=最近1次收到该包的时间戳
    var receivedMessages = [String: Int]()
    /// 当前线程是否正在执行中
    var running: Bool = false
    
    var executing: Bool = false
    var timer: Timer?
    
    /// 本属性仅作DEBUG之用：DEBUG事件观察者
    var debugObserver: ObserverCompletion?
    
    /// 单例
    static let instance: QoS4ReceiveDaemon = QoS4ReceiveDaemon()
    static func sharedInstance() -> QoS4ReceiveDaemon {
        return instance
    }
    private init() {
        CAPrint("QoS4ReciveDaemon已经init了")
    }
    
    @objc func run() {
        /// 极端情况下本次循环内可能执行时间超过了时间间隔，此处是防止在前一次还没有运行完的情况下又重复过劲行，从而出现无法预知的错误
        if !self.executing {
            self.executing = true
            
            if ClientCoreSDK.isEnableDebug() {
                CAPrint("【IMCORE-TCP】【QoS接收方】+++++ START 暂存处理线程正在运行中，当前长度\(self.receivedMessages.count)")
            }
            
            for key in self.receivedMessages.keys {
                let lastMessageTimestamp = self.receivedMessages[key]
                let delta = ToolKits.getTimeStampWithMillisecondInt() - (lastMessageTimestamp ?? 0)
                
                // 该消息包超过了生命时长，去掉之
                if delta >= Self.messageValidTime {
                    if ClientCoreSDK.isEnableDebug() {
                        CAPrint("【IMCORE-TCP】【QoS接收方】指纹为\(key)的包已生存\(delta) 毫秒(最大允许\(Self.messageValidTime)毫秒), 马上将删除之")
                    }
                    
                    self.receivedMessages.removeValue(forKey: key)
                }
            }
        }
        
        if ClientCoreSDK.isEnableDebug() {
            CAPrint("【IMCORE-TCP】【QoS接收方】+++++ END 暂存处理线程正在运行中，当前长度\(self.receivedMessages.count)")
        }
        
        self.executing = false
        
        // debug
        self.debugObserver?(nil, 2)
    }
    
    /// 保存消息的时间戳
    /// - Parameter fp: 指纹
    func saveLatestFp(fp: String?) {
        if fp == nil {
            return
        }
        
        // key=指纹码，value=当前时间戳的长整性表示
        self.receivedMessages[fp!] = ToolKits.getTimeStampWithMillisecondInt()
    }
    
    /// 启动线程
    /// - Parameter immediately: true表示立即执行线程作业，否则直到执行间隔的到来才进行首次作业的执行
    func startup(immediately: Bool) {
        self.stop()
        
        // 如果列表不为空则尝试重置生成起始时间
        if self.receivedMessages.count > 0 {
            for key in self.receivedMessages.keys {
                // 重置列表中的生存起始时间
                self.saveLatestFp(fp: key)
            }
        }
        
        // 执行延迟的单位是秒
        self.timer = Timer.scheduledTimer(timeInterval: TimeInterval(Self.checkInterval / 1000),
                                          target: self,
                                          selector: #selector(run),
                                          userInfo: nil,
                                          repeats: true)
        // 如果需要立即执行
        if immediately {
            self.timer!.fire()
        }
        
        self.running = true
        
        // debug
        self.debugObserver?(nil, 1)
    }
    
    /// 无条件中断本线程的运行
    func stop() {
        if self.timer != nil {
            if self.timer!.isValid {
                self.timer!.invalidate()
            }
            
            self.timer = nil
        }
        
        self.running = false
        
        // debug
        self.debugObserver?(nil, 0)
    }
    
    /// 线程是否正在运行中
    /// - Returns: true表示是，否则线路处于停止状态
    func isRunning() -> Bool {
        return self.running
    }
    
    /// 向列表中加入一个包的特征指纹
    /// - Parameter message: 消息对象
    func addReceived(message: Protocol?) {
        if message == nil {
            return
        }
        
        if message!.QoS {
            self.addRecievedWithFingerPrint(fp: message!.fp)
        }
    }
    
    /// 向列表中加入一个包的特征指纹
    /// - Parameter fp: 消息包的特纹特征码
    func addRecievedWithFingerPrint(fp: String?) {
        if fp == nil {
            CAPrint("【IMCORE-TCP】无效的 fingerPrintOfProtocal==null")
            return
        }
        
        if self.receivedMessages.keys.contains(fp!) {
            CAPrint("【IMCORE-TCP】【QoS接收方】指纹为 \(fp!) 的消息已经存在于接收列表中，该消息重复了（原理可能是对方因未收到应答包而错误重传导致），更新收到时间戳哦")
        }
        
        // 无条件放入已收到列表（如果已存在则覆盖之，已在存则意味着消息重复被接收，那么就用最新的时间戳更新之）
        self.saveLatestFp(fp: fp)
    }
    
    /// 指定指纹码的Protocal是否已经收到过
    /// - Parameter fp: 消息包的特纹特征码
    /// - Returns: true - 已收到，false - 未收到
    func hasReceived(fp: String?) -> Bool {
        if fp == nil {
            return false
        }
        
        return self.receivedMessages.keys.contains(fp!)
    }
    
    /// 清空缓存队列
    func clear() {
        self.receivedMessages.removeAll()
    }
    
    /// Just for DEBUG
    func setDebugObserver(debugObserver: @escaping ObserverCompletion) {
        self.debugObserver = debugObserver
    }
}
