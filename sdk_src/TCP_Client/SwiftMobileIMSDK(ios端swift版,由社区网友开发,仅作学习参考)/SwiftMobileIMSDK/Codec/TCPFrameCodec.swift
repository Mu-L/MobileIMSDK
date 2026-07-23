//
//  TCPFrameCodec.swift
//  SwiftMobileIMSDK
//
//  Created by fishbay on 2021/8/7.
//

import Foundation

class TCPFrameCodec {
    
    /**
     * MobileIMSDK中的TCP数据帧Headder（头部）字节长度（默认4字节）。
     *
     * <pre style="border: 1px solid #eaeaea;background-color: #fff6ea;border-radius: 6px;">
     * ===== 【为了妥善解决TCP的半包、粘包经典问题，使用“数据包头Header+数据包体Body”的帧组织形式】 ======
     *
     * 【即帧编码格式为】：
     * Header(存放的是body数据长度，定长4字节int整数) + Body(真正数据内容，不定长，长度应在Header的最大值之内)。
     *
     * 【举例】：
     *  以发送一个字母“A”（即body为“A”）为例，以下是编码后的完整数据帧形式：
     *  +------- Header (4 bytes)  -------|---------   Body (1 bytes) ----------+
     *  +      0x0000 0000 0000 0001      |              0x0041                 +
     *  +------ （内容为int整数1）   -------|-------（内容为字母“A”的ASCII码）------+
     *
     * 【有关GCDAsyncSocket中实现半包、粘包的处理资料】：
     *  关于GCDAsyncSocket中实现半包、粘包的处理，官方开发者指南中有详细思路，请见：
     *  https://github.com/robbiehanson/CocoaAsyncSocket/wiki/Intro_GCDAsyncSocket#reading--writing
     * ============================================ 【END】 =======================================</pre>
     */
    static var tcpFrameFixedHeaderLength: Int = 4
    
    /**
     * MobileIMSDK中的TCP数据帧Body（数据体）的最大字节长度（默认最大6KB）
    */
    static var tcpFrameMaxBodyLength: Int = 6 * 1024
    
    /// 为了妥善解决TCP的半包、粘包经典问题，MobileIMSDK中使用“数据包头Header+数据包体Body”的TCP帧组织形式
    /// - Parameter bodyData: 待编码的数据
    /// - Returns: 已编码成TCP桢的数据，数据包头Header+数据包体Body
    static func encodeFrame(bodyData: Data?) -> Data? {
        if bodyData == nil || bodyData!.count <= 0 {
            return nil
        }
        
        /// 网络字节序是大端，传输出去前要将主机字节序转为网络字节序，否则无法跟服务端正常通信
        let bodyLength = CFSwapInt32HostToBig(UInt32(bodyData!.count))
        
        /// Header中的数据=Body的数据长度int整数（即定长4字节）
        let headerData = withUnsafeBytes(of: bodyLength, Array.init)
        
        // 数据包头部就是数据的长度int值
        var data = Data.init(bytes: headerData, count: tcpFrameFixedHeaderLength)
        
        // 数据包体在数据包头后面
        data.append(bodyData!)
        
        return data
    }
    
    /// 将读取到的TCP帧中Header数据解码
    /// - Parameter headerData: header数据
    /// - Returns: body长度
    static func decodeBodyLength(headerData: Data?) -> Int {
        if headerData == nil || headerData!.count <= 0 {
            return 0
        }
        
        // 收到的网络数据为大端字节序，需要转为主机字节序
        let length = UInt32(bigEndian: headerData!.withUnsafeBytes{ $0.load(as: UInt32.self)})
        
        return Int(length)
    }
    
    /// 设置tcp帧的长度
    /// - Parameter lenght: 新的长度值
    static func setTcpFrameFixedHeaderLength(lenght: Int) {
        Self.tcpFrameFixedHeaderLength = lenght
    }
    static func getTcpFrameFixedHeaderLength() -> Int {
        return Self.tcpFrameFixedHeaderLength;
    }
    
    /// 设置tcp数据包的最大值
    /// - Parameter length: 最大值
    static func setTcpFrameMaxBodyLength(length: Int) {
        Self.tcpFrameMaxBodyLength = length
    }
    static func getTcpFrameMaxBodyLength() -> Int {
        return Self.tcpFrameMaxBodyLength
    }
}
