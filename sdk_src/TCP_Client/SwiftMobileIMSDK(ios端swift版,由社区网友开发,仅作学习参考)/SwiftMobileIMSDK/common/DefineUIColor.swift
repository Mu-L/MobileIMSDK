//
//  DefineUIColor.swift
//  Confidence
//
//  Created by fishbay on 2021/7/3.
//

import Foundation
import UIKit

// 背景色
var bgColor: UIColor {
    return rgb(r: 233, g: 235, b: 236)
}

// 深色文案颜色
var slogenColor: UIColor {
    return rgb(r: 107, g: 94, b: 94)
}

// 蓝色按钮颜色
func btnBlueBgColor(size: CGSize) -> UIImage {
    return imageFromColor(color: rgb(r: 0, g: 167, b: 234), viewSize: size)
}

// rgb颜色转换（16进制->10进制）
func rgb(r: Float, g: Float, b: Float) -> UIColor {
    return rgba(r: r, g: g, b: b, a: 1.0)
}

func rgba(r: Float, g: Float, b: Float, a: Float) -> UIColor {
    return UIColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: CGFloat(a))
}

func colorFromRGB(value: Int) -> UIColor {
    return UIColor(red: CGFloat((value & 0xFF0000) >> 16), green: CGFloat((value & 0x00FF00) >> 16), blue: CGFloat((value & 0x0000FF) >> 16), alpha: 1.0)
}

// 通过颜色获得图片
func imageFromColor(color: UIColor, viewSize: CGSize) -> UIImage {
    let rect = CGRect(x: 0, y: 0, width: viewSize.width, height: viewSize.height)

    UIGraphicsBeginImageContext(rect.size)

    let context: CGContext = UIGraphicsGetCurrentContext()!

    context.setFillColor(color.cgColor)
    context.fill(rect)

    let image = UIGraphicsGetImageFromCurrentImageContext()

    UIGraphicsGetCurrentContext()

    return image!
}

// 随机色
var randomColor: UIColor {
    UIColor(red: CGFloat(arc4random() % 256) / 255.0, green: CGFloat(arc4random() % 256) / 255.0, blue: CGFloat(arc4random() % 256) / 255.0, alpha: 1.0)
}
