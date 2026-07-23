//
//  DefineUIFont.swift
//  Confidence
//
//  Created by fishbay on 2021/7/3.
//

import Foundation
import UIKit

// 细体
func lightFont(size: CGFloat) -> UIFont {
    return UIFont(name: "HelveticaNeue-Light", size: size)!
}

// 常规体
func normalFont(size: CGFloat) -> UIFont {
    return UIFont.systemFont(ofSize: size)
}

// 常规粗体
func boldFont(size: CGFloat) -> UIFont {
    UIFont.boldSystemFont(ofSize: size)
}
