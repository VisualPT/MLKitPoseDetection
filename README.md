# MLKitPoseDetection

This is a snippet of a Flutter iOS Method Channel for Pose Detection using MLKit.



https://github.com/VisualPT/MLKitPoseDetection/assets/62311337/2707853a-804c-4741-bd65-71062f29dc26



## Introduction
The snippet in this repository allows Flutter apps to leverage the capabilities of Google's ML Kit's Pose Detection API. The package supports pose detection in "real-time". Note that there is notable latency using this implementation strategy, hence the "real time" in quotes.

## Features
* Real-time pose detection
* Extract 33 skeletal landmark points

## Installation

To use this package, add `MLKitPoseDetection` as a [dependency in your podfile](https://developers.google.com/ml-kit/vision/pose-detection).

Assemble these files in your codebase as you see fit, then in a Stateful widget, include this snippet:

```dart
...
late List<Offset> results = [];

@override
void initState() {
  super.initState();

  try {
    widget.cameraController!.startVideoRecording(onAvailable: (image) async {
      final data = await widget.inferenceService.getPoseDetection(image);
      if (mounted && data is List<Offset> && data.isNotEmpty) {
        setState(
          () => results = data,
        );
      }
    });
  } catch (e) {
    log("An error occured in the Inference Preview $e");
  }
}
...
```

Finally, use the widget.cameraController in a `CameraPreview` widget.

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).
