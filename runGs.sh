pip install ./submodules/diff-gaussian-rasterization
python train.py --eval -s /root/autodl-tmp/data/DTU/scan24 --lod 0 --voxel_size 0.001 --update_init_factor 16 --appearance_dim 0 --ratio 1  -m ./eval/scan24 --mesh -r 2
python render.py -s /root/autodl-tmp/data/DTU/scan24 -m ./eval/scan24 -r 2
python mesh_extract.py -s /mnt/f7a57ea9-f9b0-4806-966e-7f21cbc76421/xzy/data/refnerf2/ball -m ./eval/ball0 --appearance_dim 0 --data_device cpu
python evaluate_dtu_mesh.py -s /root/autodl-tmp/data/DTU/scan24 -m ./eval/scan24 --DTU /root/autodl-tmp/data/DTU-origin