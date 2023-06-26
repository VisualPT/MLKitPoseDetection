import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'isolate_utils.dart';

class InferenceService {
  static const MethodChannel _channel =
      MethodChannel('com.prod.visualpt/posedetection');

  final IsolateUtils _isolateUtils = IsolateUtils();

  bool isDetecting = false;
  Queue<CameraImage> frameQueue = Queue();

  InferenceService() {
    _isolateUtils.initIsolate();
  }

  dispose() {
    _isolateUtils.dispose();
  }

  Future<List<Offset>?> getPoseDetection(CameraImage image) async {
    try {
      if (!isDetecting) {
        frameQueue.add(image);
        final detection = await processVideoFrames();
        return detection?.toOffsets();
      }
    } catch (e) {
      log('Error during pose detection: $e');
      return [];
    }
  }

  Future<PoseDetectionResult?> processVideoFrames() async {
    if (isDetecting) {
      return null;
    }

    isDetecting = true;
    final CameraImage frame = frameQueue.removeFirst();
    final pose = await detectPose(frame);
    isDetecting = false;
    return pose;
  }

  Future<void> inference({
    required IsolateUtils isolateUtils,
    required Function handler,
    required CameraImage image,
  }) async {
    final responsePort = ReceivePort();
    isolateUtils.sendMessage(
      handler: handler,
      params: {
        'image': image,
      },
      sendPort: isolateUtils.sendPort,
      responsePort: responsePort,
    );

    final data = await responsePort.first;
    responsePort.close();
  }

  static Future<PoseDetectionResult> detectPose(CameraImage image) async {
    try {
      final Uint8List imageData = _cameraImageToBytes(image);
      final Map<String, dynamic> args = {
        "image": imageData,
        "width": image.width,
        "height": image.height,
      };
      final dynamic result =
          await _channel.invokeMethod('getPoseDetection', args);
      final poses = PoseDetectionResult.fromJson(result.first["landmarks"]);
      return poses;
    } catch (e) {
      log('Error during pose detection: $e');
      return PoseDetectionResult(poses: []);
    }
  }

  static Uint8List _cameraImageToBytes(CameraImage image) {
    final planes = image.planes;
    final numBytes = planes
        .map((plane) => plane.bytes.lengthInBytes)
        .reduce((value, element) => value + element);
    final bytes = Uint8List(numBytes);
    int offset = 0;
    for (var plane in planes) {
      bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return bytes;
  }
}

class PoseDetectionResult {
  static final Map<String, int> _landmarkIndices = {
    'Nose': 0,
    'LeftEyeInner': 1,
    'LeftEye': 2,
    'LeftEyeOuter': 3,
    'RightEyeInner': 4,
    'RightEye': 5,
    'RightEyeOuter': 6,
    'LeftEar': 7,
    'RightEar': 8,
    'MouthLeft': 9,
    'MouthRight': 10,
    'LeftShoulder': 11,
    'RightShoulder': 12,
    'LeftElbow': 13,
    'RightElbow': 14,
    'LeftWrist': 15,
    'RightWrist': 16,
    'LeftPinkyFinger': 17,
    'RightPinkyFinger': 18,
    'LeftIndexFinger': 19,
    'RightIndexFinger': 20,
    'LeftThumb': 21,
    'RightThumb': 22,
    'LeftHip': 23,
    'RightHip': 24,
    'LeftKnee': 25,
    'RightKnee': 26,
    'LeftAnkle': 27,
    'RightAnkle': 28,
    'LeftHeel': 29,
    'RightHeel': 30,
    'LeftToe': 31,
    'RightToe': 32,
  };
  late List<PoseLandmarks> poses;

  PoseDetectionResult({required this.poses});

  List<Offset> toOffsets() {
    if (poses.isNotEmpty) {
      final List<Offset> offsets = List.filled(33, Offset.zero);
      for (final landmark in poses) {
        final int index = _landmarkIndices[landmark.type] ?? -1;
        if (index != -1) {
          offsets[index] = Offset(landmark.x, landmark.y);
        } else {
          throw "Invalid landmark detected ${landmark.type}";
        }
      }
      return offsets;
    }
    return [];
  }

  factory PoseDetectionResult.fromJson(List<Object?> data) {
    late List<PoseLandmarks> poses = List.empty(growable: true);
    for (var element in data) {
      final json = element as Map<dynamic, dynamic>;
      poses.add(PoseLandmarks.fromJson(json));
    }
    return PoseDetectionResult(poses: poses);
  }
}

class PoseLandmarks {
  final String type;
  final double x;
  final double y;
  final double z;
  final double inFrameLikelihood;

  PoseLandmarks(
      {required this.type,
      required this.x,
      required this.y,
      required this.z,
      required this.inFrameLikelihood});

  factory PoseLandmarks.fromJson(Map<dynamic, dynamic> json) {
    return PoseLandmarks(
      type: json['type'] as String,
      x: json['x'] as double,
      y: json['y'] as double,
      z: json['z'] as double,
      inFrameLikelihood: json['inFrameLikelihood'] as double,
    );
  }
}
