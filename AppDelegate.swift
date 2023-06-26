import Flutter
import UIKit
import MLKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        let poseDetectionChannel = FlutterMethodChannel(name: "com.prod.visualpt/posedetection",
                                                        binaryMessenger: controller.binaryMessenger)
        
        poseDetectionChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            // This method is invoked on the UI thread.
            // Handle battery messages.
            guard call.method == "getPoseDetection" else {
                result(FlutterMethodNotImplemented)
                return
            }
            self?.performPoseDetection(call: call, result: result)
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func performPoseDetection(call: FlutterMethodCall,  result: @escaping FlutterResult)  {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            //Create an instance of PoseDetector
            let options = PoseDetectorOptions()
            options.detectorMode = .stream
            let poseDetector = PoseDetector.poseDetector(options: options)
            
            //print("Pose detector created")
            // Extract the image data from the arguments
            guard let arguments = call.arguments as? [String: Any] else {
                result("Invalid arguments")
                return
            }
            guard let imageData = arguments["image"] as? FlutterStandardTypedData else {
                result("Couldn't find image data")
                return
            }
            guard let width = arguments["width"] as? Int, let height = arguments["height"] as? Int else {
                result("Invalid width or height")
                return
            }
            //print("Received image data size: \(imageData) with width \(width) and height \(height)")
            guard let data = imageData.data as Data? else {
                result("Invalid image data")
                return
            }
            //print("Received data: \(!data.isEmpty)")
            // Convert Data to UIImage
            guard let image: UIImage = self.convertYUV420ToUIImage(nv21Data: data, width: width, height: height) else {
                result("Failed to convert data to UIImage")
                return
            }
//            //print("Created image: \(image)")
//            let renderer = UIGraphicsImageRenderer(size: image.size)
//            //print("Renderer?")
//            let _ = renderer.image { (context) in
//                image.draw(in: CGRect(origin: .zero, size: image.size))
//            }
            //print("Image size: \(image.size)")
            // Convert UIImage to VisionImage
            guard let visionImage = self.convertUIImageToVisionImage(image: image) as VisionImage? else {
                result("Failed to convert UIImage to VisionImage")
                return
            }
            
            //print("Data converted to VisionImage")
            
            // Perform pose detection
            var results: [Pose]?
            do {
                results = try poseDetector.results(in: visionImage)
            } catch let error {
                result("Failed to detect pose with error: \(error.localizedDescription).")
                return
            }
            //print("Results output: \(results ?? [])")
            
            // Convert poses to dictionaries
            let poseDictionaries = results?.map { pose in
                return self.poseToDictionary(pose: pose)
            } ?? []
            
            //print("Dictionary Converted")
            //print("Returning: \(!poseDictionaries.isEmpty)")
            result(poseDictionaries)
            return
        } 
    }
        
    func convertUIImageToVisionImage(image: UIImage) -> VisionImage? {
        guard image.cgImage != nil else {
            return nil
        }
        return VisionImage(image: image)
    }
    
    func poseToDictionary(pose: Pose) -> [String: Any] {
        var poseDictionary: [String: Any] = [:]
        
        var landmarkDictionaries: [[String: Any]] = []
        for landmark in pose.landmarks {
            let landmarkDictionary: [String: Any] = [
                "type": landmark.type,
                "x": landmark.position.x,
                "y": landmark.position.y,
                "z": landmark.position.z,
                "inFrameLikelihood": landmark.inFrameLikelihood
            ]
            landmarkDictionaries.append(landmarkDictionary)
        }
        poseDictionary["landmarks"] = landmarkDictionaries
        
        return poseDictionary
    }
    
    func convertYUV420ToUIImage(nv21Data: Data, width: Int, height: Int) -> UIImage? {
        guard let cgImage = convertYUV420ToCGImage(nv21Data: nv21Data, width: width, height: height) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func convertYUV420ToCGImage(nv21Data: Data, width: Int, height: Int) -> CGImage? {
        guard let providerRef = CGDataProvider(data: nv21Data as CFData) else {
            return nil
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo = [CGBitmapInfo.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)]
        
        let renderingIntent: CGColorRenderingIntent = .defaultIntent
        
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo, provider: providerRef, decode: nil, shouldInterpolate: true, intent: renderingIntent)
    }
}
