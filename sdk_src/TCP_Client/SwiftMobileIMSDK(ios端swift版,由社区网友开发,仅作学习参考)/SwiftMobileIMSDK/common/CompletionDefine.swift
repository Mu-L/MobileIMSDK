//
//  CompletionDefine.swift
//  SwiftMobileIMSDK
//
//  Created by fishbay on 2021/8/2.

//  本接口中定义了一些用于回调的block类型

import Foundation

/*!
 *  通用回调，应用场景是模拟Java中的Obsrver观察者模式。(参数重的 _ 表示调用的时候可以忽略参数名称)
 *
 *  @param observerble      此参数通常为nil，字段意义可自行定义
 *  @param data              通常为回调时的数据（字段意义可自行定义），可为nil
 */
typealias ObserverCompletion = (_ observerble: Any?, _ data: Any?) -> Void

/*!
 *  Socket连接结果回调。
 *
 *  @param connectRsult：true - 表示连接成功，false - 否则表示连接失败
 */
typealias ConnectionCompletion = (_ connectResult: Bool?) -> Void
