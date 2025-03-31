pip install ./submodules/diff-gaussian-rasterization
python train.py -s /root/autodl-tmp/data/DTU/scan24 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan24 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan24 -m ./eval/scan24 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan24 -m ./eval/scan24 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan24 -m ./eval/scan24 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan37 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan37 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan37 -m ./eval/scan37 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan37 -m ./eval/scan37 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan37 -m ./eval/scan37 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan40 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan40 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan40 -m ./eval/scan40 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan40 -m ./eval/scan40 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan40 -m ./eval/scan40 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan55 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan55 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan55 -m ./eval/scan55 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan55 -m ./eval/scan55 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan55 -m ./eval/scan55 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan63 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan63 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan63 -m ./eval/scan63 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan63 -m ./eval/scan63 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan63 -m ./eval/scan63 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan65 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan65 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan65 -m ./eval/scan65 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan65 -m ./eval/scan65 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan65 -m ./eval/scan65 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan69 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan69 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan69 -m ./eval/scan69 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan69 -m ./eval/scan69 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan69 -m ./eval/scan69 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan83 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan83 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan83 -m ./eval/scan83 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan83 -m ./eval/scan83 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan83 -m ./eval/scan83 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan97 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan97 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan97 -m ./eval/scan97 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan97 -m ./eval/scan97 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan97 -m ./eval/scan97 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan105 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan105 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan105 -m ./eval/scan105 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan105 -m ./eval/scan105 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan105 -m ./eval/scan105 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan106 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan106 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan106 -m ./eval/scan106 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan106 -m ./eval/scan106 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan106 -m ./eval/scan106 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan110 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan110 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan110 -m ./eval/scan110 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan110 -m ./eval/scan110 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan110 -m ./eval/scan110 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan114 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan114 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan114 -m ./eval/scan114 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan114 -m ./eval/scan114 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan114 -m ./eval/scan114 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan118 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan118 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan118 -m ./eval/scan118 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan118 -m ./eval/scan118 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan118 -m ./eval/scan118 --DTU /root/autodl-tmp/data/DTU-origin

python train.py -s /root/autodl-tmp/data/DTU/scan122 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan122 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan122 -m ./eval/scan122 -r 2
python mesh_extract.py -s /root/autodl-tmp/data/DTU/scan122 -m ./eval/scan122 --appearance_dim 0 -r 2
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan122 -m ./eval/scan122 --DTU /root/autodl-tmp/data/DTU-origin

/usr/bin/shutdown
