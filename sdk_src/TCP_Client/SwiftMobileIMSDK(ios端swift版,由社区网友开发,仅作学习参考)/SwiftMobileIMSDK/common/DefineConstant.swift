//
//  DefineConstant.swift
//  Confidence
//
//  Created by fishbay on 2021/7/3.
//

import Foundation
import UIKit

// 获取系统版本
let IOS_VERSION = UIDevice.current.systemVersion

// 获取设备屏幕尺寸
let SCREEN_WIDTH = UIScreen.main.bounds.size.width
let SCREEN_HEIGHT = UIScreen.main.bounds.size.height

// cell 高度
let MINE_CELL_HEIGHT: CGFloat = 60

// TextField 的高度
let FIELD_HEIGHT = 50

// 左侧 margin
let LEFT_MARGIN: CGFloat = 30

// 分页参数
let PAGE_SIZE = 10

// 屏幕适配
func autoFit(number: CGFloat) -> CGFloat {
    return (number / 375.0 * SCREEN_WIDTH)
}

func autoFit(number: Int) -> Int {
    return Int((CGFloat(number) / 375.0 * SCREEN_WIDTH))
}

func autoFitLandscape(number: CGFloat) -> CGFloat {
    return (number / 375.0 * SCREEN_HEIGHT)
}

func autoFitLandscape(number: Int) -> Int {
    return Int((CGFloat(number) / 375.0 * SCREEN_HEIGHT))
}

func autoFitFrame(frame: CGRect) -> CGRect {
    return CGRect(x: autoFit(number: frame.origin.x),
                  y: autoFit(number: frame.origin.y),
                  width: autoFit(number: frame.size.width),
                  height: autoFit(number: frame.size.height))
}

// 打印日志
public func CAPrint(_ object: @autoclosure () -> Any?,
                    _ file: String = #file,
                    _ function: String = #function,
                    _ line: Int = #line)
{
    #if DEBUG
        guard let value = object() else {
            return
        }
        var stringRepresentation: String?

        if let value = value as? CustomDebugStringConvertible {
            stringRepresentation = value.debugDescription
        } else if let value = value as? CustomStringConvertible {
            stringRepresentation = value.description
        } else {
            fatalError("gLog only works for values that conform to CustomDebugStringConvertible or CustomStringConvertible")
        }

        let gFormatter = DateFormatter()
        gFormatter.dateFormat = "HH:mm:ss:SSS"
        let timestamp = gFormatter.string(from: Date())
        let queue = Thread.isMainThread ? "UI" : "BG"
        let fileURL = NSURL(string: file)?.lastPathComponent ?? "Unknown file"

        if let string = stringRepresentation {
            print("✅ \(timestamp) {\(queue)} \(fileURL) > \(function)[\(line)]: \(string)")
        } else {
            print("✅ \(timestamp) {\(queue)} \(fileURL) > \(function)[\(line)]: \(value)")
        }
    #endif
}
