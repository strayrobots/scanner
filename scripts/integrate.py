import os
import open3d as o3d
import numpy as np
from scipy.spatial.transform import Rotation
from argparse import ArgumentParser
from PIL import Image
import cv2
import skvideo.io

MAX_DEPTH = 25.0
DEPTH_WIDTH = 256
DEPTH_HEIGHT = 192

def read_args():
    parser = ArgumentParser()
    parser.add_argument('path', type=str, help="Path to StrayScanner folder to process.")
    parser.add_argument('--frames', action='store_true', help="Visualize coordinate frames.")
    parser.add_argument('--point-clouds', action='store_true', help="Visualize point clouds one-by-one.")
    parser.add_argument('--integrate', action='store_true', help="Visualize point clouds one-by-one.")
    parser.add_argument('--every', type=int, default=50)
    return parser.parse_args()

T_AC = np.array([[0., 1., 0., 0.],
        [1., 0., 0., 0.],
        [0., 0., -1., 0.],
        [0., 0., 0., 1.]])

def _resize_camera_matrix(camera_matrix, scale_x, scale_y):
    fx = camera_matrix[0, 0]
    fy = camera_matrix[1, 1]
    cx = camera_matrix[0, 2]
    cy = camera_matrix[1, 2]
    return np.array([[fx * scale_x, 0.0, cx * scale_x],
        [0., fy * scale_y, cy * scale_y],
        [0., 0., 1.0]])


def read_data(flags):
    intrinsics = np.loadtxt(os.path.join(flags.path, 'camera_matrix.csv'), delimiter=',')
    odometry = np.loadtxt(os.path.join(flags.path, 'odometry.csv'), delimiter=',')
    poses = []
    for line in odometry:
        # x, y, z, qx, qy, qz, qw
        position = line[:3]
        quaternion = line[3:]
        T_WA = np.eye(4)
        T_WA[:3, :3] = Rotation.from_quat(quaternion).as_matrix()
        T_WA[:3, 3] = position
        poses.append(T_WA @ T_AC)
    return { 'poses': poses, 'intrinsics': intrinsics }

def load_depth(path):
    depth = Image.open(path).resize((DEPTH_HEIGHT, DEPTH_WIDTH), resample=Image.NEAREST)
    depth = np.array(depth).astype(np.uint16)
    meters = (depth[:, :, 0] + (depth[:, :, 1] + 256 * depth[:, :, 2]) / 1000.0).astype(np.float32)
    return o3d.geometry.Image(meters)

def main():
    flags = read_args()

    data = read_data(flags)
    geometries = []
    if flags.frames:
        geometries += show_frames(flags, data)
    if flags.point_clouds:
        geometries += point_clouds(flags, data)
    if flags.integrate:
        geometries = integrate(flags, data)
    o3d.visualization.draw_geometries(geometries)

def get_intrinsics(intrinsics):
    intrinsics_scaled = _resize_camera_matrix(intrinsics, DEPTH_WIDTH / 1920, DEPTH_HEIGHT / 1280)
    return o3d.camera.PinholeCameraIntrinsic(width=DEPTH_HEIGHT, height=DEPTH_WIDTH, fx=intrinsics_scaled[1, 1],
        fy=intrinsics_scaled[0, 0], cx=intrinsics_scaled[1, 2], cy=intrinsics_scaled[0, 2])

def show_frames(flags, data):
    frames = [o3d.geometry.TriangleMesh.create_coordinate_frame().scale(0.25, np.zeros(3))]
    for i, T_WC in enumerate(data['poses']):
        if not i % flags.every == 0:
            continue
        print(f"Frame {i}", end="\r")
        mesh = o3d.geometry.TriangleMesh.create_coordinate_frame().scale(0.1, np.zeros(3))
        frames.append(mesh.transform(T_WC))
    return frames

def point_clouds(flags, data):
    pcs = []
    intrinsics = get_intrinsics(data['intrinsics'])
    pc = o3d.geometry.PointCloud()
    meshes = []
    for i, T_WC in enumerate(data['poses']):
        if i % flags.every != 0:
            continue
        print(f"Point cloud {i}", end="\r")
        T_CW = np.linalg.inv(T_WC)
        depth = load_depth(os.path.join(flags.path, 'depth', f'{i:06}.png'))
        X = o3d.geometry.PointCloud.create_from_depth_image(depth, intrinsics, extrinsic=T_CW, depth_scale=1.0)
        pc += X.uniform_down_sample(every_k_points=5)
    return [pc]

def integrate(flags, data):
    volume = o3d.pipelines.integration.ScalableTSDFVolume(
            voxel_length=4.0 / 256.0,
            sdf_trunc=0.04,
            color_type=o3d.pipelines.integration.TSDFVolumeColorType.RGB8)

    intrinsics = get_intrinsics(data['intrinsics'])

    rgb_path = os.path.join(flags.path, 'rgb.mp4')
    video = skvideo.io.vreader(rgb_path)
    for i, (T_WC, rgb) in enumerate(zip(data['poses'], video)):
        print(f"Integrating frame {i:06}", end='\r')
        depth_path = os.path.join(flags.path, 'depth', f'{i:06}.png')
        depth = load_depth(depth_path)
        rgb = Image.fromarray(rgb)
        rgb = rgb.resize((DEPTH_HEIGHT, DEPTH_WIDTH))
        rgb = np.array(rgb)
        rgbd = o3d.geometry.RGBDImage.create_from_color_and_depth(
            o3d.geometry.Image(rgb), depth,
            depth_scale=1.0, convert_rgb_to_intensity=False)

        volume.integrate(rgbd, intrinsics, np.linalg.inv(T_WC))
    mesh = volume.extract_triangle_mesh()
    mesh.compute_vertex_normals()
    return [mesh]

if __name__ == "__main__":
    main()

