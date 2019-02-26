//
//  BMKMapView+Inertia.swift
//  BMKMapView+Inertia
//
//  Created by yinpan on 2018/6/28.
//  Copyright © 2018年 yinpan. All rights reserved.
//

import Foundation
import UIKit
import Aspects
import BaiduMapAPI_Map

private var BMKMapViewAllowIneritaScalableKey = "BMKMapViewAllowIneritaScalableKey"
private var BMKMapViewScaleIneritaKey         = "BMKMapViewScaleIneritaKey"
private var BMKMapViewDisplayLinkKey          = "BMKMapViewDisplayLinkKey"
private let BMKMapViewScaleDampingNumber      = 10

extension BMKMapView {

    /// 是否允许地图惯性缩放，默认false
    public var isInertiaScalable: Bool {
        get{
            let isAllow = objc_getAssociatedObject(self, &BMKMapViewAllowIneritaScalableKey) as? Bool
            return isAllow ?? false
        }
        set{
            objc_setAssociatedObject(self, &BMKMapViewAllowIneritaScalableKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
            // 如果 self.inertia 属性存在的话，则表示已经hook过，反之未Hook
            if objc_getAssociatedObject(self, &BMKMapViewScaleIneritaKey) == nil {
                do {
                    try handleRelevantPrivateView()
                } catch {
                    print(error)
                }
            }
        }
    }

    private var inertia: Inertia {
        get{
            guard let inertia = objc_getAssociatedObject(self, &BMKMapViewScaleIneritaKey) as? Inertia else {
                let newInertia = Inertia()
                self.inertia = newInertia
                return newInertia
            }
            return inertia
        }
        set{
            objc_setAssociatedObject(self, &BMKMapViewScaleIneritaKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var displayLink: CADisplayLink? {
        get{
            return objc_getAssociatedObject(self, &BMKMapViewDisplayLinkKey) as? CADisplayLink
        }
        set{
            objc_setAssociatedObject(self, &BMKMapViewDisplayLinkKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }


    /// 设置地图缩放惯性系数
    ///
    /// - Parameter coefficient: 系数（即一元二次方程系数a，a值越大，惯性越小）| 默认是30
    func setupInertiaScaling(coefficient: Double = QuadraticFunction.defalutInertiaCoefficient) {
        guard coefficient > 0 else { return }
        endDisplayLink()
        inertia.setupInertiaCoefficient(coefficient)
    }

    /// 通过等时设置惯性缩放动画
    private func inertiaAnimation() {
        let dampingTime = (inertia.inertiaTime - inertia.moveTime) / Double(BMKMapViewScaleDampingNumber)
        for i in 1...BMKMapViewScaleDampingNumber {
            let processTime = dampingTime * Double(i)
            let realTime = inertia.moveTime + processTime
            let realLevel = Float(inertia.quadratic.calculate(realTime))
            let t: DispatchTime = .now() + Double(processTime)
            DispatchQueue.main.asyncAfter(deadline: t) {
                self.zoomLevel = realLevel
//                print("realLevel：\(realLevel)")
            }
        }
    }

    /// 通过CADisplayLink逐帧刷新惯性动画
    private func startDisplayLink() {
        endDisplayLink()
        self.perform(#selector(endDisplayLink), with: nil, afterDelay: inertia.inertiaTimeConsuming)
        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
        displayLink?.add(to: RunLoop.current, forMode: RunLoop.Mode.default)
        displayLink?.isPaused = false
    }

    /// 结束CADisplayLink惯性动画
    @objc private func endDisplayLink() {
        if let displayLink = displayLink {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(endDisplayLink), object: nil)
            displayLink.isPaused = true
            displayLink.invalidate()
        }
        displayLink = nil
    }

    @objc private func handleDisplayLink() {
        inertia.zoomDisplayLinkCount += 1
//        print("zoomDisplayLinkCount = \(inertia.zoomDisplayLinkCount)")
        let currentFPSLevel = inertia.calculateZoomLevel(with: inertia.zoomDisplayLinkCount)
        self.zoomLevel = currentFPSLevel
        // 当惯性动画已执行时间大于1s（即60帧）时，或者惯性动画已执行时间大于计算的惯性时间时，结束惯性动画
        if inertia.zoomDisplayLinkCount > 60 || Double(inertia.zoomDisplayLinkCount)/60.0 > inertia.inertiaTimeConsuming  {
            endDisplayLink()
        }
    }
}

private let AspectsMessagePrefix = "aspects__"
private let InternalMapViewClassName  = "BMKInternalMapView"
private let TapDetectingViewClassName = "BMKTapDetectingView"

extension BMKMapView {

    private enum HookMethod: String {
        case handleDoubleBeginTouchPoint = "handleDoubleBeginTouchPoint"
        case handleDoubleEndTouchPoint   = "handleDoubleEndTouchPoint"
        case handleScale                 = "handleScale:"
    }

    enum HookError: Error, CustomStringConvertible {
        case viewNotFound(String)
        case methodNotFound(String)
        case aspectHookError(Error)

        var description: String {
            switch self {
            case .viewNotFound(let type):
                return "未找到 \(type) 视图"
            case .methodNotFound(let message):
                return message
            case .aspectHookError(let error):
                return error.localizedDescription
            }
        }
    }

    /// 处理百度地图相关私有方法
    /// 找到 BMKTapDetectingView 对象，对其内部方法进行Hook
    ///
    /// - Throws: Hook失败异常
    private func handleRelevantPrivateView() throws -> () {

        guard let internalMapViewClass = NSClassFromString(InternalMapViewClassName) else {
            throw HookError.viewNotFound(InternalMapViewClassName)
        }
        guard let tapDetectingViewClass = NSClassFromString(TapDetectingViewClassName) else {
            throw HookError.viewNotFound(TapDetectingViewClassName)
        }
        // 按步骤查找到 BMKMapView 中的 BMKTapDetectingView 对象，并对其进行方法Hook
        // BMKMapView -> BMKInternalMapView -> BMKTapDetectingView
        let internalSubViews = subviews.filter { $0.isKind(of: internalMapViewClass) }
        guard internalSubViews.count > 0 else {
            throw HookError.viewNotFound(InternalMapViewClassName)
        }
        let tapDetectingView = internalSubViews[0].subviews.filter{ $0.isKind(of: tapDetectingViewClass) }
        guard tapDetectingView.count > 0 else {
            throw HookError.viewNotFound(TapDetectingViewClassName)
        }
        do {
            try hookMethodsInTapDetectingView(tapDetectingView.first!)
        } catch {
            throw error
        }
    }

    private func hookMethodsInTapDetectingView(_ tapDetectingView: UIView) throws -> () {
        guard type(of: tapDetectingView).description() == TapDetectingViewClassName else {
            throw HookError.viewNotFound(TapDetectingViewClassName)
        }
        // 获取 tapDetectingView 的方法列表
        guard let methodList = getMethodList(cls: type(of: tapDetectingView)) else {
            throw HookError.methodNotFound("The method list for the \(TapDetectingViewClassName) was not found.")
        }

        let hookMethods: [String] = [HookMethod.handleDoubleBeginTouchPoint,
                                     HookMethod.handleDoubleEndTouchPoint,
                                     HookMethod.handleScale].map{$0.rawValue}

        // 确保 BMKTapDetectingView 存在 hookMethods 的所有方法，否则跳出HOOK
        guard hookMethods.reduce(true, { $0 && methodList.contains($1)}) else {
            let methods = hookMethods.filter { !methodList.contains($0) }
            throw HookError.methodNotFound("The methods for \(methods) was not found.")
        }

        /*
         @convention
         1. 修饰 Swift 中的函数类型，调用 C 的函数时候，可以传入修饰过 @convention(c) 的函数类型，匹配 C 函数参数中的函数指针。
         2. 修饰 Swift 中的函数类型，调用 Objective-C 的方法时候，可以传入修饰过 @convention(block) 的函数类型，匹配 Objective-C 方法参数中的 block 参数
         */
        let block: @convention(block) (AnyObject?) -> Void = { [weak self]
            info in
            guard let aspectInfo = info as? AspectInfo else { return }
            self?.hookMethod(aspectInfo: aspectInfo)
        }

        // Hook Method
        for method in hookMethods {
            do {
                try tapDetectingView.aspect_hook(NSSelectorFromString(method), with: AspectOptions(rawValue: 0), usingBlock: block)
            } catch let error {
                throw HookError.aspectHookError(error)
            }
        }
    }

    private func getMethodList(cls: AnyClass) -> [String]? {
        var methodCount:UInt32 = 0
        guard let methodList = class_copyMethodList(cls, &methodCount) else {
            return nil
        }
        var list: [String] = []
        //打印方法
        for i in 0..<Int(methodCount) {
            let selector = method_getName(methodList[i])
            list.append(NSStringFromSelector(selector))
        }
        free(methodList)
        return list
    }

    private func hookMethod(aspectInfo: AspectInfo) {
        guard isInertiaScalable, let invocation = aspectInfo.originalInvocation() else { return }
        let sel = NSStringFromSelector(invocation.selector)
//        print("[\(TapDetectingViewClassName)·Hook] - \(sel)")
        if sel == AspectsMessagePrefix + HookMethod.handleDoubleBeginTouchPoint.rawValue {
            hookedMethod_handleDoubleBeginTouchPoint()
        } else if sel == AspectsMessagePrefix + HookMethod.handleDoubleEndTouchPoint.rawValue {
            hookedMethod_handleDoubleEndTouchPoint()
        } else if sel == AspectsMessagePrefix + HookMethod.handleScale.rawValue {
            hookedMethod_handleScale(aspectInfo.arguments())
        }
    }
}

extension BMKMapView {

    fileprivate func hookedMethod_handleDoubleBeginTouchPoint() {
        endDisplayLink()
        inertia.reset()
        let date = Date()
        inertia.startTime = date.timeIntervalSince1970
        inertia.startLevel = Double(self.zoomLevel)
    }

    fileprivate func hookedMethod_handleDoubleEndTouchPoint() {
        let date = Date()
        inertia.endTime = date.timeIntervalSince1970
        inertia.endLevel = Double(self.zoomLevel)

        if isInertiaScalable {
            // 计算系数
            inertia.calculationCoefficient { [weak self] in
                // 开始惯性动画
                self?.startDisplayLink()
            }
        }
    }

    fileprivate func hookedMethod_handleScale(_ args: [Any]?) {
        guard let args = args as? [NSNumber], let value = args.first?.floatValue else { return }
        if value > 0 {
            inertia.quadratic.a = -fabs(inertia.quadratic.a)
        } else {
            inertia.quadratic.a = fabs(inertia.quadratic.a)
        }
    }
}

private class Inertia {

    /// 设置缩放惯性超时时间，超时后无惯性效果
    let zoomInertiaTimeOut: TimeInterval = 0.7

    var startTime: TimeInterval = 0
    var endTime: TimeInterval = 0
    var inertiaLevel: Double = 0
    var startLevel: Double = 0
    var endLevel: Double = 0
    var inertiaTime: TimeInterval = 0

    var moveTime: TimeInterval = 0

    var inertiaTimeConsuming: Double {
        let time = inertiaTime - moveTime
        return time > 0 ? time : 0
    }

    /// 惯性帧缩放执行次数
    var zoomDisplayLinkCount: Int = 0

    // 一元二次方程 y = ax^2 + bx + c
    var quadratic = QuadraticFunction()

    /// 计算二次方程的系数：b、c
    ///
    /// - Parameter completion: 计算完成后回调
    func calculationCoefficient(completion: ()->()) {
        moveTime = endTime - startTime
        // 缩放时间超过0.8s，默认不处理惯性
        guard moveTime < zoomInertiaTimeOut, moveTime > 0 else { return }
        /**
         y = ax^2 + bx + c;
         x = 0 , y = c
         且经过 (0,_startZoomLevel)
         */
        quadratic.c = Double(startLevel)

        // b = (y - c - ax^2)/x
        quadratic.b = (endLevel - startLevel - quadratic.a * pow(moveTime, 2)) / moveTime

        // 导数 y = 2ax + b
        // 当 y = 0 , x = -b/2a
        inertiaTime = -quadratic.b/(2 * quadratic.a)
        // 抛物线顶点
        inertiaLevel = quadratic.a * pow(inertiaTime, 2) + quadratic.b * inertiaTime + quadratic.c
        // 当惯性时间大于0时，执行惯性动画
        if inertiaTimeConsuming > 0 {
            completion()
        }
    }

    /// 更加CADisplayLink累计执行次数，计算当前地图ZoomLevel值
    ///
    /// - Parameter displayLinkCount: CADisplayLink累计执行次数
    /// - Returns: 当前ZoomLevel值
    func calculateZoomLevel(with displayLinkCount: Int) -> Float {
        let processTime = (inertiaTimeConsuming) / 60.0 * Double(displayLinkCount)
        let realTime = moveTime + processTime
        let realLevel = Float(quadratic.calculate(realTime))
        return realLevel
    }

    func reset() {
        startTime = 0
        endTime = 0
        moveTime = 0
        startLevel = 0
        endLevel = 0
        inertiaLevel = 0
        inertiaTime = 0

        /// 惯性帧缩放执行设置为0
        zoomDisplayLinkCount = 0
    }


    /// 设置惯性系数
    func setupInertiaCoefficient(_ coefficient: Double = QuadraticFunction.defalutInertiaCoefficient) {
        quadratic.a = coefficient
    }
}

private struct QuadraticFunction {

    static let defalutInertiaCoefficient: Double = 25

    /// 系数A，数值越大，抛物线开口越大，即惯性效果越小
    var a: Double = QuadraticFunction.defalutInertiaCoefficient
    var b: Double = 0
    var c: Double = 0

    func calculate(_ x: Double) -> Double {
        return a * pow(x, 2) + b * x + c
    }
}



