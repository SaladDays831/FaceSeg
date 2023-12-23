# FaceSeg

**FaceSeg** is a facial segmentation package written in Swift. It uses Apple's Vision framework and its' facial observations + landmarks to create different images with segmented faces

## Requirements
iOS 11.0+ / macOS 10.13+

## Installation
**Swift Package Manager:**
-   File > Swift Packages > Add Package Dependency
-   Add  `https://github.com/SaladDays831/FaceSeg.git`

## Usage

Create an instance of `FaceSeg`, set its' delegate.
Create a `FaceSegConfiguration` object, and set whatever you need to `true`. 
**Every property is `false` by default** to save on performance. If you don't explicitly set the needed settings in `FaceSegConfiguration` - only `metadata` will be returned in the result
```
let faceSeg = FaceSeg()
faceSeg.delegate = self

let configuration = FaceSegConfiguration()
// Modify the configuration as per your needs
faceSeg.configuration = configuration

faceSeg.process(myCoolImage)
```

```
extension ViewController: FaceSegDelegate { 
    func didFinishProcessing(_ result: FaceSegResult) {
        print("Finished processing image") 
    }

    func didFinishWithError(_ error: FaceSegError) {
        print("FaceSeg finished with error: \(error.errorString)")
    }
}
```
A working example can be found in the `FaceSegDemo` folder

### `FaceSegConfiguration` parameters

**drawDebugImage**
Original image with face bounding boxes, paths, and landmarks

**drawFacesImage** 
Image with the segmented faces on a transparent background. The location/scale of the faces is preserved

**drawCutoutFacesImage**
Original image with transparent holes instead of the detected faces

**drawFacesInBoundingBoxes**
An array of detected faces as separate images

**faceInBoundingBoxImageHeight**
The size (width == height) of the resulting images in the `facesInBoundingBoxes` array


### Note ⚠️
Running on the simulator doesn't work. This is an issue with Vision introduced with iOS 15.
https://developer.apple.com/forums/thread/690605

## Licence
FaceSeg is released under the MIT license. See LICENSE for details.
