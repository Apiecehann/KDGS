# UniGS: Unified Geometry Reconstruction for Specular and Semi-transparent Surfaces

This repository contains the official implementation of the paper: **"UniGS: Unified Geometry Reconstruction for Specular and Semi-transparent Surfaces via 3D Gaussian Splatting"**.

## Abstract
While 3D Gaussian Splatting (3DGS) has revolutionized real-time photorealistic rendering, extracting high-fidelity geometry from complex specular and semi-transparent scenes remains a significant challenge. We present **UniGS**, a unified geometry reconstruction framework designed to overcome these limitations. First, we establish a consistent analytic formulation for depth and normal estimation, eliminating biases found in heuristic approximations. Second, **to resolve the shape-radiance ambiguity in specular highlights**, we propose a Surface Integrity Constraint that prevents geometric collapse by minimizing ray-accumulated depth. Third, **to tackle the multi-surface ambiguity in semi-transparent objects**, we develop an Anisotropic Opacity strategy coupled with Multi-Layer Depth Extraction to explicitly recover occluded back-surfaces. Extensive experiments on five benchmarks, including DTU, BlendedMVS, and three specular/transparent datasets, demonstrate that UniGS outperforms state-of-the-art methods in geometric accuracy while maintaining real-time efficiency.

## Installation

The environment setup is similar to [3DGS](https://github.com/graphdeco-inria/gaussian-splatting) and [Scaffold-GS](https://github.com/city-super/Scaffold-GS).

```bash
git clone --recursive [https://github.com/YourRepo/UniGS.git](https://github.com/YourRepo/UniGS.git)
cd UniGS

conda create -n unigs python=3.8
conda activate unigs

# Install pytorch (adjust version according to your cuda)
pip install torch==1.12.1+cu113 torchvision==0.13.1+cu113 -f [https://download.pytorch.org/whl/torch_stable.html](https://download.pytorch.org/whl/torch_stable.html)

# Install submodules
pip install -r requirements.txt
Data Preparation
We support standard Colmap datasets (e.g., DTU, Mip-NeRF 360) and BlendedMVS. Please organize your data as follows:

data/
|-- dtu/
|   |-- scan24/
|   |   |-- images/
|   |   |-- sparse/
|   |-- ...
|-- blended_mvs/
|   |-- ...
Usage
Training
To train a scene (e.g., DTU Scan 24) with our Surface Integrity Constraint enabled:

Bash

python train.py -s data/dtu/scan24 -m output/dtu_scan24 --lambda_reg 0.1 --lambda_geo 0.05
Geometry Extraction
To extract the mesh using our Multi-Layer Depth Extraction:

Bash

python extract_mesh.py -m output/dtu_scan24 --iteration 30000 --depth_trunc 0.5
Citation
If you find this code useful for your research, please consider citing:

代码段

@article{unigs2026,
  title={UniGS: Unified Geometry Reconstruction for Specular and Semi-transparent Surfaces via 3D Gaussian Splatting},
  author={Anonymous Authors},
  journal={Submitted to The Visual Computer},
  year={2026}
}
Acknowledgement
This code is built upon Scaffold-GS. We thank the authors for their open-source code.
