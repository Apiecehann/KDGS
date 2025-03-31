import os
import torch
from random import randint
import sys
from scene import Scene, GaussianModel
from argparse import ArgumentParser, Namespace
from arguments import ModelParams, PipelineParams, OptimizationParams
import matplotlib.pyplot as plt
import math
import numpy as np
from scene.cameras import Camera
import open3d as o3d
import open3d.core as o3c
from scene.dataset_readers import sceneLoadTypeCallbacks
from utils.camera_utils import cameraList_from_camInfos, camera_to_JSON
import json
from gaussian_renderer import render, prefilter_voxel
from tqdm import tqdm
try:
    from diff_gaussian_rasterization import SparseGaussianAdam
    SPARSE_ADAM_AVAILABLE = True
except:
    SPARSE_ADAM_AVAILABLE = False

def load_camera(args, lod=0):
    if os.path.exists(os.path.join(args.source_path, "sparse")):
        scene_info = sceneLoadTypeCallbacks["Colmap"](args.source_path, args.images, args.eval, lod)
    elif os.path.exists(os.path.join(args.source_path, "transforms_train.json")):
        print("Found transforms_train.json file, assuming Blender data set!")
        scene_info = sceneLoadTypeCallbacks["Blender"](args.source_path, args.white_background, args.eval)
    return cameraList_from_camInfos(scene_info.train_cameras, 1.0, args)

def extract_mesh(dataset, pipeline, checkpoint_iterations=None):
    with torch.no_grad():
        gaussians = GaussianModel(dataset.feat_dim, dataset.n_offsets, dataset.voxel_size, dataset.update_depth,
                                  dataset.update_init_factor, dataset.update_hierachy_factor, dataset.use_feat_bank,
                                  dataset.appearance_dim, dataset.ratio, dataset.add_opacity_dist, dataset.add_cov_dist,
                                  dataset.add_color_dist)
        gaussians.eval()
        output_path = os.path.join(dataset.model_path, "point_cloud")
        iteration = 0
        if checkpoint_iterations is None:
            for folder_name in os.listdir(output_path):
                iteration = max(iteration, int(folder_name.split('_')[1]))
        else:
            iteration = checkpoint_iterations

        output_ply_path = os.path.join(output_path, "iteration_" + str(iteration), "point_cloud.ply")
        output_mlp_path = os.path.join(output_path, "iteration_" + str(iteration))
        gaussians.load_ply_sparse_gaussian(output_ply_path)
        gaussians.load_mlp_checkpoints(output_mlp_path)
        print(f'Loaded gaussians from {output_path}')

        bg_color = [1, 1, 1]
        background = torch.tensor(bg_color, dtype=torch.float32, device="cuda")
        viewpoint_cam_list = load_camera(dataset)

        depth_list = []
        color_list = []
        alpha_thres = 0.5
        for viewpoint_cam in viewpoint_cam_list:
            # Rendering offscreen from that camera
            voxel_visible_mask = prefilter_voxel(viewpoint_cam, gaussians, pipeline, background)
            render_pkg = render(viewpoint_cam, gaussians, pipeline, background, visible_mask=voxel_visible_mask)
            rendered_img = torch.clamp(render_pkg["render"], min=0, max=1.0).cpu().numpy().transpose(1, 2, 0)
            depth = render_pkg["median_depth"].clone()
            if viewpoint_cam.alpha_mask is not None:
                depth[(viewpoint_cam.alpha_mask < 0.5)] = 0
            color_list.append(np.ascontiguousarray(rendered_img))
            depth[render_pkg["mask"] < alpha_thres] = 0
            depth_list.append(depth[0].cpu().numpy())

        torch.cuda.empty_cache()
        voxel_size = 0.002
        o3d_device = o3d.core.Device("CPU:0")
        vbg = o3d.t.geometry.VoxelBlockGrid(attr_names=('tsdf', 'weight', 'color'),
                                            attr_dtypes=(o3c.float32,
                                                         o3c.float32,
                                                         o3c.float32),
                                            attr_channels=((1), (1), (3)),
                                            voxel_size=voxel_size,
                                            block_resolution=16,
                                            block_count=50000,
                                            device=o3d_device)
        for color, depth, viewpoint_cam in zip(color_list, depth_list, viewpoint_cam_list):
            depth = o3d.t.geometry.Image(depth)
            depth = depth.to(o3d_device)
            color = o3d.t.geometry.Image(color)
            color = color.to(o3d_device)
            W, H = viewpoint_cam.image_width, viewpoint_cam.image_height
            fx = W / (2 * math.tan(viewpoint_cam.FoVx / 2.))
            fy = H / (2 * math.tan(viewpoint_cam.FoVy / 2.))
            intrinsic = np.array([[fx, 0, float(W) / 2], [0, fy, float(H) / 2], [0, 0, 1]], dtype=np.float64)
            intrinsic = o3d.core.Tensor(intrinsic)
            extrinsic = o3d.core.Tensor((viewpoint_cam.world_view_transform.T).cpu().numpy().astype(np.float64))
            frustum_block_coords = vbg.compute_unique_block_coordinates(
                depth,
                intrinsic,
                extrinsic,
                1.0, 8.0
            )
            vbg.integrate(
                frustum_block_coords,
                depth,
                color,
                intrinsic,
                extrinsic,
                1.0, 8.0
            )

        mesh = vbg.extract_triangle_mesh()
        mesh.compute_vertex_normals()
        o3d.io.write_triangle_mesh(os.path.join(dataset.model_path, "recon.ply"), mesh.to_legacy())
        print("done!")


if __name__ == "__main__":
    parser = ArgumentParser(description="Training script parameters")
    lp = ModelParams(parser)
    pp = PipelineParams(parser)
    parser.add_argument("--checkpoint_iterations", nargs="+", type=int, default=None)
    args = parser.parse_args(sys.argv[1:])
    with torch.no_grad():
        extract_mesh(lp.extract(args), pp.extract(args), args.checkpoint_iterations)