#
# Copyright (C) 2023, Inria
# GRAPHDECO research group, https://team.inria.fr/graphdeco
# All rights reserved.
#
# This software is free for non-commercial, research and evaluation use 
# under the terms of the LICENSE.md file.
#
# For inquiries contact  george.drettakis@inria.fr
#

import torch
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap

def mse(img1, img2):
    return (((img1 - img2)) ** 2).view(img1.shape[0], -1).mean(1, keepdim=True)

def psnr(img1, img2):
    mse = (((img1 - img2)) ** 2).view(img1.shape[0], -1).mean(1, keepdim=True)
    return 20 * torch.log10(1.0 / torch.sqrt(mse))

def any2color(any):
    # 找到输入张量的最小值和最大值
    min_d = torch.quantile(any, 0.01)
    max_d = torch.quantile(any, 0.99)
    # 对输入张量进行归一化处理，将其值缩放到 [0, 1] 范围
    depth = (any - min_d) / (max_d - min_d)
    depth[depth < 0] = 0
    depth[depth >= 1] = 1
    # 将归一化后的深度值重复三次以形成一个形状为 (H, W, 3) 的数组，模拟 RGB 图像
    depth_draw = depth.detach().cpu().numpy()
    turbo = plt.colormaps['turbo']
    colored_depth = turbo(depth_draw)
    print(colored_depth.shape)
    # 将 numpy 数组转换为 PyTorch 张量，并将其放置到与输入张量相同的设备上
    colored_depth = torch.from_numpy(colored_depth).to(depth.device).permute([2, 0, 1])
    return colored_depth


def depth2rgb(depth, mask):
    sort_d = torch.sort(depth[mask.to(torch.bool)])[0]
    min_d = sort_d[len(sort_d) // 100 * 5]
    max_d = sort_d[len(sort_d) // 100 * 95]
    depth = (depth - min_d) / (max_d - min_d) * 0.9 + 0.1
    viridis = ListedColormap(plt.cm.viridis(np.linspace(0, 1, 256)))
    depth_draw = viridis(depth.detach().cpu().numpy()[0])[..., :3]
    depth_draw = torch.from_numpy(depth_draw).to(depth.device).permute([2, 0, 1]) * mask
    return depth_draw