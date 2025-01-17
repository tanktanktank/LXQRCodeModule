//
//  QRCodeViewController.swift
//  XLApprovalProgress
//
//  Created by LIXIANG on 2019/11/25.
//  Copyright © 2019 XIANGLI. All rights reserved.
//

import UIKit
import ImageIO
import Photos
import AVFoundation

/// 类型
public  enum LXQRCodeType {
    ///失败（授权失败等等）
    case error(String)
    ///扫描成功
    case success(String)
}

public typealias CallBack = ((LXQRCodeType) -> ())

// MARK: - LXQRCodeViewController
open class LXQRCodeViewController: UIViewController {
      
    
   ///回调
   open var callBack: CallBack?
       
    /// 二维码的view
    open lazy var qrCodeView: LXQRCodeView = {
        let qrCodeView = LXQRCodeView(frame: self.view.bounds)
        qrCodeView.delegate = self
        return qrCodeView
    }()
    
   /// 绘画
   private lazy var captureSession = AVCaptureSession()
   
   /// 设备
   private lazy var captureDevice = AVCaptureDevice.default(for: .video)

   /// Video 预览层
   private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
   
   /// 初始化放大倍数为0
   private var initialPinchZoom: CGFloat = 0

   /// 判断是否有继承  如果有集成 必须传true 否则会存在问题
   private var isInherit: Bool = false
   public required init(_ isInherit: Bool) {
      self.isInherit = isInherit
      super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .background).async {
                self.captureSession.startRunning()
            }
            qrCodeView.setTimer()
        }
     }
    
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
          setQRCodeViewUI()

          // 设置相机权限
          getCameraAuthorizationStatus()
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }

    }
    
     /***************继承用到*************/
     /// 即成用到的回调
     open func setCallBack(qrCode: String) {}
     ///点击返回
     open func setGoBack() {}
    /***************继承用到*************/

    
    /// 设置 扫描二维码view
     fileprivate func setQRCodeViewUI() {
        qrCodeView.setTimer()
        view.addSubview(qrCodeView)
     }
        
    //相册授权
    fileprivate func getCameraAuthorizationStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch status {
        case .restricted,.denied:
            DispatchQueue.main.async { [weak self] in
                self?.callBack?(.error("Please go to iPhone‘s Setting>Privacy>Enable Camera access"))
            }
        case .authorized:
            DispatchQueue.main.async {
                self.setSessionInput()
                self.setSessionOutput()
                self.setPreviewLayer()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video) { (granted) in
                if granted {
                    DispatchQueue.main.async {
                      self.setSessionInput()
                      self.setSessionOutput()
                      self.setPreviewLayer()
                    }
                }
            }
        default:
            break
        }
    }
    
    // MARK: - Video AVCaptureDeviceInput
    fileprivate func setSessionInput() {
        //当前设备不存在,直接返回
        guard let device = captureDevice else { return }
        do {
           let newInput = try AVCaptureDeviceInput(device: device)
            captureSession.beginConfiguration()
     
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
            }
            captureSession.commitConfiguration()
        }catch {
            print("创建输入设备异常")
        }
    }
    
    // MARK: - Video AVCaptureDeviceInput
    fileprivate func setSessionOutput() {
    
        let dataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
            dataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            dataOutput.metadataObjectTypes = [.qr,.aztec]
            dataOutput.rectOfInterest = CGRect(x: qrCodeView.qrRect.origin.y / qrCodeView.frame.height, y: qrCodeView.qrRect.origin.x / qrCodeView.frame.width, width:qrCodeView.qrRect.height / qrCodeView.frame.height, height: qrCodeView.qrRect.width / qrCodeView.frame.width)
            
        }
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue:  DispatchQueue.main)
        }
    }
    
    // MARK: - Video AVCaptureVideoPreviewLayer
    fileprivate func setPreviewLayer() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = .resizeAspectFill
        videoPreviewLayer?.frame = self.view.bounds
        if videoPreviewLayer != nil {
        self.view.layer.insertSublayer(videoPreviewLayer!, at: 0)
       
        }
    }
    
    /// 播放音乐
    fileprivate func playSound() {

        var soundID : SystemSoundID = 0
        let fileName = Bundle(for: LXQRCodeViewController.self).path(forResource: "LXQRCode", ofType: "bundle")! + "/lxQrCodeVoice.wav"
        let fileUrl = URL(fileURLWithPath: fileName)
        AudioServicesCreateSystemSoundID(fileUrl as CFURL, &soundID)
        AudioServicesPlaySystemSound(soundID)
        AudioServicesPlaySystemSoundWithCompletion(soundID, {
            AudioServicesDisposeSystemSoundID(soundID)
        })
    }
    /// 判断程序是否有访问相册的权限
    fileprivate var isSupportPhotoAlbum: Bool {
        
        let authStatus = PHPhotoLibrary.authorizationStatus()
        if authStatus == .denied || authStatus == .restricted {
            return false
        }
        return true
    }
    
    ///光灯控制
    private func setflashLight() {
        if captureDevice != nil && (captureDevice?.hasTorch ?? false) {
            try? captureDevice?.lockForConfiguration()
            if qrCodeView.flashlightBtn.isSelected {
                captureDevice?.torchMode = .on
            }else {
                captureDevice?.torchMode = .off
            }
            captureDevice?.unlockForConfiguration()
        }
    }
}

extension LXQRCodeViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        if self.qrCodeView.flashlightBtn.isSelected { return }

        guard let cfDiction: NSDictionary =  CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate) else { return }
         let dic: NSDictionary = NSDictionary(dictionary:  cfDiction)
         guard  let imgDic: NSDictionary = dic[kCGImagePropertyExifDictionary] as? NSDictionary else { return }
        guard let brightValue = imgDic[kCGImagePropertyExifBrightnessValue as String] else { return }

         DispatchQueue.main.async { [weak self] in
            self?.qrCodeView.flashlightBtn.isHidden = (brightValue as! CGFloat) >= -1
        }
    }
}

extension LXQRCodeViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {

         guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject else { return }
         ///停止绘画
         captureSession.stopRunning()
         ///停止定时器
         qrCodeView.stopTimer()
         /// 播放音乐
         playSound()
         let qrStr = object.stringValue ?? ""
         qrCodeView.flashlightBtn.isSelected = !qrCodeView.flashlightBtn.isSelected
          
        ///判断是否有继承
        if isInherit {
            setCallBack(qrCode: qrStr)
        }else {
             ///扫描回调
             callBack?(.success(qrStr))
            
             /// 扫描成功返回
             if self.navigationController == nil {
                self.dismiss(animated: false, completion: nil)
             }else{
                self.navigationController?.popViewController(animated: false)
             }
         }
     }
}

extension LXQRCodeViewController: UIImagePickerControllerDelegate , UINavigationControllerDelegate {
    
    ///点击使用图片, 使用该图片
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        dismiss(animated: true, completion: nil)
        guard let image = info[.originalImage] as? UIImage else {             callBack?(.error("Fail to select photo"))
            return
        }
        guard let qrCodeStr = LXQRCode.qrCodeString(with: image) else {
            callBack?(.error("QR code recognition failed"))
            return
        }
        
        ///判断是否有继承
        if isInherit {
            setCallBack(qrCode: qrCodeStr)
        }else {
            ///扫描回调
            callBack?(.success(qrCodeStr))
        }
    }
}

extension LXQRCodeViewController: LXQRCodeViewDelegate {
    
    public func qrCodeView(_ view: LXQRCodeView, type: LXQRCodeViewType) {
        
        
        switch type {
        case .album:
            
            let picker = UIImagePickerController()
            picker.delegate = self
            //判断是否有上传相册权限
            if isSupportPhotoAlbum {
                picker.sourceType = .photoLibrary
                picker.modalPresentationStyle = .fullScreen
                present(picker, animated: true, completion: nil)
            }else{
                let msg = "Failed to open the album, please open the photo album permission in the phone settings"
                let alertController = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                alertController.modalPresentationStyle = .fullScreen
                present(alertController, animated: true, completion: nil)
            }
         
        case .flashlight:
            setflashLight()
        case .cancel:
            if isInherit {
                setGoBack()
            }else {
                 /// 扫描成功返回
                 if self.navigationController == nil {
                    self.dismiss(animated: false, completion: nil)
                 }else{
                    self.navigationController?.popViewController(animated: false)
                 }
             }
        case .numsOfTap:
            if captureDevice == nil { return }
            do {
                try captureDevice?.lockForConfiguration()
                if captureDevice?.videoZoomFactor == 1.0 {
                    let current: CGFloat = 2
                    guard let maxFactor = captureDevice?.activeFormat.videoMaxZoomFactor else { return }
                    if current <  maxFactor {
                        captureDevice?.ramp(toVideoZoomFactor: current , withRate: 2)
                    }
                }else {
                    captureDevice?.ramp(toVideoZoomFactor: 1.0 , withRate: 2)
                }
                captureDevice?.unlockForConfiguration()
            }catch { }
        }
       
    }
    
    public func qrCodeView(_ view: LXQRCodeView, gesture: UIPinchGestureRecognizer) {
        
        if captureDevice == nil { return }
        if gesture.state == .began {
            if let vZoom = captureDevice?.videoZoomFactor  {
                  initialPinchZoom = vZoom
            }
        }
        if gesture.state == .changed {
            do {
               try captureDevice?.lockForConfiguration()
                           
               let scale = gesture.scale
               var zoomFactor: CGFloat = 0
               if scale <= 1.0 {
                   zoomFactor = initialPinchZoom - pow(captureDevice?.activeFormat.videoMaxZoomFactor ?? 10, 1.0 - gesture.scale)
               }else {
                   zoomFactor = initialPinchZoom + pow(captureDevice?.activeFormat.videoMaxZoomFactor ?? 10, (gesture.scale - 1) * 0.5) - 1
               }
               zoomFactor = min(10, zoomFactor)
               zoomFactor = max(1, zoomFactor)
                
               captureDevice?.videoZoomFactor = zoomFactor
               captureDevice?.unlockForConfiguration()
            }catch { }
        }
    }
}
