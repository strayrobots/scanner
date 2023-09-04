
# Data Specification

This document describes the data format recorded by the [Stray Scanner iOS app](https://apps.apple.com/us/app/stray-scanner/id1557051662). Note, that it is slightly different from the [dataset format](/formats/data.md). Stray Scanner datasets can be converted using the [import command](/tutorials/import.md).

The collected datasets are each contained in a folder, named after a random hash, for example `71de12f9`. A dataset folder has the following directory structure:

```
camera_matrix.csv
odometry.csv
imu.csv
depth/
  - 000000.png
  - 000001.png
  - ...
confidence/
  - 000000.png
  - 000001.png
  - ...
rgb.mp4
```

`rgb.mp4` is an HEVC encoded video, which contains the recorded data from the iPhone's camera.

The `depth/` directory contains the depth maps. One `.png` file per rgb frame. Each of these is a 16 bit grayscale png image. They have a height of 192 elements and width of 256 elements. The values are the measured depth in millimeters, for that pixel position. In [OpenCV](https://docs.opencv.org/4.5.5/), these can be read with `cv2.imread(depth_frame_path, -1)`.

The `confidence/` directory contains confidence maps corresponding to each depth map. They are grayscale png files encoding 192 x 256 element matrices. The values are either 0, 1 or 2. A higher value means a higher confidence.

The `camera_matrix.csv` is a 3 x 3 matrix containing the [camera intrinsic parameters](https://en.wikipedia.org/wiki/Camera_resectioning#Intrinsic_parameters).

The `odometry.csv` file contains the camera positions for each frame. The first line is a header. The meaning of the fields are:

| Field | <div style="width: 500px">Meaning</div> |
|---|---|
| timestamp | Timestamp in seconds |
| frame | Frame number to which this pose corresponds to e.g. `000005` |
| x | x coordinate in meters from when the session was started |
| y | y coordinate in meters from when the session was started |
| z | z coordinate in meters from when the session was started |
| qx | x component of quaternion representing camera pose rotation |
| qy | y component of quaternion representing camera pose rotation |
| qz | z component of quaternion representing camera pose rotation |
| qw | w component of quaternion representing camera pose rotation |

The `imu.csv` file contains timestamps, linear acceleration readings and angular rotation readings. The first line is a header. The meaning of the fields are:

| Field | <div style="width: 500px">Meaning</div> |
|---|---|
| timestamp | Timestamp in seconds |
| a\_x | Acceleration in m/s^2 in x direction |
| a\_y | Acceleration in m/s^2 in y direction |
| a\_z | Acceleration in m/s^2 in z direction |
| alpha\_x | Rotation in rad/s around the x-axis |
| alpha\_y | Rotation in rad/s around the y-axis |
| alpha\_z | Rotation in rad/s around the z-axis |

