/*
 * Copyright (C) 2023, Inria
 * GRAPHDECO research group, https://team.inria.fr/graphdeco
 * All rights reserved.
 *
 * This software is free for non-commercial, research and evaluation use 
 * under the terms of the LICENSE.md file.
 *
 * For inquiries contact  george.drettakis@inria.fr
 */

#include "forward.h"
#include "auxiliary.h"
#include <cooperative_groups.h>
#include <cooperative_groups/reduce.h>
namespace cg = cooperative_groups;

__device__ __constant__ float pi = 3.14159265358979323846f;

// Forward method for converting the input spherical harmonics
// coefficients of each Gaussian to a simple RGB color.
__device__ glm::vec3 computeColorFromSH(int idx, int deg, int max_coeffs, const glm::vec3* means, glm::vec3 campos, const float* shs, bool* clamped)
{
	// The implementation is loosely based on code for 
	// "Differentiable Point-Based Radiance Fields for 
	// Efficient View Synthesis" by Zhang et al. (2022)
	glm::vec3 pos = means[idx];
	glm::vec3 dir = pos - campos;
	dir = dir / glm::length(dir);

	glm::vec3* sh = ((glm::vec3*)shs) + idx * max_coeffs;
	glm::vec3 result = SH_C0 * sh[0];

	if (deg > 0)
	{
		float x = dir.x;
		float y = dir.y;
		float z = dir.z;
		result = result - SH_C1 * y * sh[1] + SH_C1 * z * sh[2] - SH_C1 * x * sh[3];

		if (deg > 1)
		{
			float xx = x * x, yy = y * y, zz = z * z;
			float xy = x * y, yz = y * z, xz = x * z;
			result = result +
				SH_C2[0] * xy * sh[4] +
				SH_C2[1] * yz * sh[5] +
				SH_C2[2] * (2.0f * zz - xx - yy) * sh[6] +
				SH_C2[3] * xz * sh[7] +
				SH_C2[4] * (xx - yy) * sh[8];

			if (deg > 2)
			{
				result = result +
					SH_C3[0] * y * (3.0f * xx - yy) * sh[9] +
					SH_C3[1] * xy * z * sh[10] +
					SH_C3[2] * y * (4.0f * zz - xx - yy) * sh[11] +
					SH_C3[3] * z * (2.0f * zz - 3.0f * xx - 3.0f * yy) * sh[12] +
					SH_C3[4] * x * (4.0f * zz - xx - yy) * sh[13] +
					SH_C3[5] * z * (xx - yy) * sh[14] +
					SH_C3[6] * x * (xx - 3.0f * yy) * sh[15];
			}
		}
	}
	result += 0.5f;

	// RGB colors are clamped to positive values. If values are
	// clamped, we need to keep track of this for the backward pass.
	clamped[3 * idx + 0] = (result.x < 0);
	clamped[3 * idx + 1] = (result.y < 0);
	clamped[3 * idx + 2] = (result.z < 0);
	return glm::max(result, 0.0f);
}

// Forward version of 2D covariance matrix computation
__device__ float3 computeCov2D(const float3& mean, float focal_x, float focal_y, float tan_fovx, float tan_fovy, const float* cov3D, const float* viewmatrix)
{
	// The following models the steps outlined by equations 29
	// and 31 in "EWA Splatting" (Zwicker et al., 2002).
	// Additionally considers aspect / scaling of viewport.
	// Transposes used to account for row-/column-major conventions.
	float3 t = transformPoint4x3(mean, viewmatrix);

	const float limx = 1.3f * tan_fovx;
	const float limy = 1.3f * tan_fovy;
	const float txtz = t.x / t.z;
	const float tytz = t.y / t.z;
	t.x = min(limx, max(-limx, txtz)) * t.z;
	t.y = min(limy, max(-limy, tytz)) * t.z;

	glm::mat3 J = glm::mat3(
		focal_x / t.z, 0.0f, -(focal_x * t.x) / (t.z * t.z),
		0.0f, focal_y / t.z, -(focal_y * t.y) / (t.z * t.z),
		0, 0, 0);

	glm::mat3 W = glm::mat3(
		viewmatrix[0], viewmatrix[4], viewmatrix[8],
		viewmatrix[1], viewmatrix[5], viewmatrix[9],
		viewmatrix[2], viewmatrix[6], viewmatrix[10]);

	glm::mat3 T = W * J;

	glm::mat3 Vrk = glm::mat3(
		cov3D[0], cov3D[1], cov3D[2],
		cov3D[1], cov3D[3], cov3D[4],
		cov3D[2], cov3D[4], cov3D[5]);

	glm::mat3 cov = glm::transpose(T) * glm::transpose(Vrk) * T;

	// Apply low-pass filter: every Gaussian should be at least
	// one pixel wide/high. Discard 3rd row and column.
	cov[0][0] += 0.3f;
	cov[1][1] += 0.3f;
	return { float(cov[0][0]), float(cov[0][1]), float(cov[1][1]) };
}


// Forward version of 2D covariance matrix computation
__device__ bool computeCov2DNew(const float3& mean, float focal_x, float focal_y, float tan_fovx, float tan_fovy, const float* cov3D, const float* viewmatrix,
                             float* cov2D, float* camera_plane, float3* output_normal, float2* ray_plane, float& coef, float* invraycov3Ds = nullptr)
{
	// The following models the steps outlined by equations 29
	// and 31 in "EWA Splatting" (Zwicker et al., 2002). 
	// Additionally considers aspect / scaling of viewport.
	// Transposes used to account for row-/column-major conventions.
	float3 t = transformPoint4x3(mean, viewmatrix);

	const float limx = 1.3f * tan_fovx;
	const float limy = 1.3f * tan_fovy;
	float txtz = t.x / t.z;
	float tytz = t.y / t.z;
	t.x = min(limx, max(-limx, txtz)) * t.z;
	t.y = min(limy, max(-limy, tytz)) * t.z;
	txtz = t.x / t.z;
	tytz = t.y / t.z;

	glm::mat3 J = glm::mat3(
		focal_x / t.z, 0.0f, -(focal_x * t.x) / (t.z * t.z),
		0.0f, focal_y / t.z, -(focal_y * t.y) / (t.z * t.z),
		0, 0, 0);

	glm::mat3 W = glm::mat3(
		viewmatrix[0], viewmatrix[4], viewmatrix[8],
		viewmatrix[1], viewmatrix[5], viewmatrix[9],
		viewmatrix[2], viewmatrix[6], viewmatrix[10]);

	glm::mat3 T = W * J;

	glm::mat3 Vrk = glm::mat3(
		cov3D[0], cov3D[1], cov3D[2],
		cov3D[1], cov3D[3], cov3D[4],
		cov3D[2], cov3D[4], cov3D[5]);

	glm::mat3 cov = glm::transpose(T) * glm::transpose(Vrk) * T;
    const float kernel_size = 0.3f;
	cov2D[0] = float(cov[0][0] + kernel_size);
	cov2D[1] = float(cov[0][1]);
	cov2D[2] = float(cov[1][1] + kernel_size);
	const float det_0 = max(1e-6, cov[0][0] * cov[1][1] - cov[0][1] * cov[0][1]);
	const float det_1 = max(1e-6, (cov[0][0] + kernel_size) * (cov[1][1] + kernel_size) - cov[0][1] * cov[0][1]);
	coef = sqrt(det_0 / (det_1+1e-6) + 1e-6);
	if (det_0 <= 1e-6 || det_1 <= 1e-6) coef = 0.0f;

	glm::mat3 Vrk_eigen_vector;
	glm::vec3 Vrk_eigen_value;
	int D = glm_modification::findEigenvaluesSymReal(Vrk,Vrk_eigen_value,Vrk_eigen_vector);

	unsigned int min_id = Vrk_eigen_value[0]>Vrk_eigen_value[1]? (Vrk_eigen_value[1]>Vrk_eigen_value[2]?2:1):(Vrk_eigen_value[0]>Vrk_eigen_value[2]?2:0);

	glm::mat3 Vrk_inv;
	bool well_conditioned = Vrk_eigen_value[min_id]>0.00000001;
	glm::vec3 eigenvector_min;

	if(well_conditioned)
	{
		glm::mat3 diag = glm::mat3( 1/Vrk_eigen_value[0], 0, 0,
									0, 1/Vrk_eigen_value[1], 0,
									0, 0, 1/Vrk_eigen_value[2] );
		Vrk_inv = Vrk_eigen_vector * diag * glm::transpose(Vrk_eigen_vector);
	}
	else
	{
		eigenvector_min = Vrk_eigen_vector[min_id];
		Vrk_inv = glm::outerProduct(eigenvector_min,eigenvector_min);
	}

	glm::mat3 cov_cam_inv = glm::transpose(W) * Vrk_inv * W;
	glm::vec3 uvh = {txtz, tytz, 1};
	glm::vec3 uvh_m = cov_cam_inv * uvh;
	glm::vec3 uvh_mn = glm::normalize(uvh_m);

	if(isnan(uvh_mn.x)|| D==0)
	{
		for(int ch = 0; ch < 6; ch++)
			camera_plane[ch] = 0;
		*output_normal = {0,0,0};
		*ray_plane = {0,0};
	}
	else
	{
		float u2 = txtz * txtz;
		float v2 = tytz * tytz;
		float uv = txtz * tytz;

		float l = sqrt(t.x*t.x+t.y*t.y+t.z*t.z);
		glm::mat3 nJ = glm::mat3(
			1 / t.z, 0.0f, -(t.x) / (t.z * t.z),
			0.0f, 1 / t.z, -(t.y) / (t.z * t.z),
			t.x/l, t.y/l, t.z/l);

		glm::mat3 nJ_inv = glm::mat3(
			v2 + 1,	-uv, 		0,
			-uv,	u2 + 1,		0,
			-txtz,	-tytz,		0
		);
		
		float vbn = glm::dot(uvh_mn, uvh);
		float factor_normal = l / (u2+v2+1);
		glm::vec3 plane = nJ_inv * (uvh_mn/max(vbn,0.0000001f));
		float nl = u2+v2+1;
		glm::vec2 camera_plane_x = {(-(v2 + 1)*t.z+plane[0]*t.x)/nl/focal_x, (uv*t.z+plane[1]*t.x)/nl/focal_y};
		glm::vec2 camera_plane_y = {(uv*t.z+plane[0]*t.y)/nl/focal_x, (-(u2 + 1)*t.z+plane[1]*t.y)/nl/focal_y};
		glm::vec2 camera_plane_z = {(t.x+plane[0]*t.z)/nl/focal_x, (t.y+plane[1]*t.z)/nl/focal_y};

		*ray_plane = {plane[0]*l/nl/focal_x, plane[1]*l/nl/focal_y};

		camera_plane[0] = camera_plane_x.x;
		camera_plane[1] = camera_plane_x.y;
		camera_plane[2] = camera_plane_y.x;
		camera_plane[3] = camera_plane_y.y;
		camera_plane[4] = camera_plane_z.x;
		camera_plane[5] = camera_plane_z.y;


		glm::vec3 ray_normal_vector = {-plane[0]*factor_normal, -plane[1]*factor_normal, -1};
		glm::vec3 cam_normal_vector = nJ * ray_normal_vector;
		glm::vec3 normal_vector = glm::normalize(cam_normal_vector);

		*output_normal = {normal_vector.x, normal_vector.y, normal_vector.z};

	}
	return well_conditioned;
}

// Forward method for converting scale and rotation properties of each
// Gaussian to a 3D covariance matrix in world space. Also takes care
// of quaternion normalization.
__device__ void computeCov3D(const glm::vec3 scale, float mod, const glm::vec4 rot, float* cov3D)
{
	// Create scaling matrix
	glm::mat3 S = glm::mat3(1.0f);
	S[0][0] = mod * scale.x;
	S[1][1] = mod * scale.y;
	S[2][2] = mod * scale.z;

	// Normalize quaternion to get valid rotation
	glm::vec4 q = rot;// / glm::length(rot);
	float r = q.x;
	float x = q.y;
	float y = q.z;
	float z = q.w;

	// Compute rotation matrix from quaternion
	glm::mat3 R = glm::mat3(
		1.f - 2.f * (y * y + z * z), 2.f * (x * y - r * z), 2.f * (x * z + r * y),
		2.f * (x * y + r * z), 1.f - 2.f * (x * x + z * z), 2.f * (y * z - r * x),
		2.f * (x * z - r * y), 2.f * (y * z + r * x), 1.f - 2.f * (x * x + y * y)
	);

	glm::mat3 M = S * R;

	// Compute 3D world covariance matrix Sigma
	glm::mat3 Sigma = glm::transpose(M) * M;

	// Covariance is symmetric, only store upper right
	cov3D[0] = Sigma[0][0];
	cov3D[1] = Sigma[0][1];
	cov3D[2] = Sigma[0][2];
	cov3D[3] = Sigma[1][1];
	cov3D[4] = Sigma[1][2];
	cov3D[5] = Sigma[2][2];
}

// Perform initial steps for each Gaussian prior to rasterization.
template<int C>
__global__ void preprocessCUDA(int P, int D, int M,
	const float* orig_points,
	const glm::vec3* scales,
	const float scale_modifier,
	const glm::vec4* rotations,
	const float* opacities,
	const float* shs,
	bool* clamped,
	const float* cov3D_precomp,
	const float* colors_precomp,
	const float* viewmatrix,
	const float* projmatrix,
	const glm::vec3* cam_pos,
	const int W, int H,
	const float tan_fovx, float tan_fovy,
	const float focal_x, float focal_y,
	int* radii,
	float2* points_xy_image,
	float3* view_points,
	float* depths,
	float* camera_planes,
	float2* ray_planes,
	float3* normals,
	float* cov3Ds,
	float* rgb,
	float4* conic_opacity,
	const dim3 grid,
	uint32_t* tiles_touched,
	bool prefiltered,
	float* invraycov3Ds,
	float* ts,
	bool* conditions)
{
	auto idx = cg::this_grid().thread_rank();
	if (idx >= P)
		return;

	// Initialize radius and touched tiles to 0. If this isn't changed,
	// this Gaussian will not be processed further.
	radii[idx] = 0;
	tiles_touched[idx] = 0;

	// Perform near culling, quit if outside.
	float3 p_view;
	if (!in_frustum(idx, orig_points, viewmatrix, projmatrix, prefiltered, p_view))
		return;

	// Transform point by projecting
	float3 p_orig = { orig_points[3 * idx], orig_points[3 * idx + 1], orig_points[3 * idx + 2] };
	float4 p_hom = transformPoint4x4(p_orig, projmatrix);
	float p_w = 1.0f / (p_hom.w + 0.0000001f);
	float3 p_proj = { p_hom.x * p_w, p_hom.y * p_w, p_hom.z * p_w };

	// If 3D covariance matrix is precomputed, use it, otherwise compute
	// from scaling and rotation parameters. 
	const float* cov3D;
	if (cov3D_precomp != nullptr)
	{
		cov3D = cov3D_precomp + idx * 6;
	}
	else
	{
		computeCov3D(scales[idx], scale_modifier, rotations[idx], cov3Ds + idx * 6);
		cov3D = cov3Ds + idx * 6;
	}

    float cov2D[3];
	float ceof;
	// Compute 2D screen-space covariance matrix
    bool condition = computeCov2DNew(p_orig, focal_x, focal_y, tan_fovx, tan_fovy, cov3D, viewmatrix, cov2D, camera_planes + idx * 6, normals + idx, ray_planes + idx, ceof, invraycov3Ds + idx * 6);
    ts[idx] = sqrt(p_view.x*p_view.x+p_view.y*p_view.y+p_view.z*p_view.z);
	const float3 cov = {cov2D[0], cov2D[1], cov2D[2]};
	// Invert covariance (EWA algorithm)
	float det = (cov.x * cov.z - cov.y * cov.y);
	if (det == 0.0f)
		return;
	float det_inv = 1.f / det;
	float3 conic = { cov.z * det_inv, -cov.y * det_inv, cov.x * det_inv };

	// Compute extent in screen space (by finding eigenvalues of
	// 2D covariance matrix). Use extent to compute a bounding rectangle
	// of screen-space tiles that this Gaussian overlaps with. Quit if
	// rectangle covers 0 tiles. 
	float mid = 0.5f * (cov.x + cov.z);
	float lambda1 = mid + sqrt(max(0.1f, mid * mid - det));
	float lambda2 = mid - sqrt(max(0.1f, mid * mid - det));
	float my_radius = ceil(3.f * sqrt(max(lambda1, lambda2)));
	float2 point_image = { ndc2Pix(p_proj.x, W), ndc2Pix(p_proj.y, H) };
	uint2 rect_min, rect_max;
	getRect(point_image, my_radius, rect_min, rect_max, grid);
	if ((rect_max.x - rect_min.x) * (rect_max.y - rect_min.y) == 0)
		return;

	// If colors have been precomputed, use them, otherwise convert
	// spherical harmonics coefficients to RGB color.
	if (colors_precomp == nullptr)
	{
		glm::vec3 result = computeColorFromSH(idx, D, M, (glm::vec3*)orig_points, *cam_pos, shs, clamped);
		rgb[idx * C + 0] = result.x;
		rgb[idx * C + 1] = result.y;
		rgb[idx * C + 2] = result.z;
	}

	// Store some useful helper data for the next steps.
	depths[idx] = p_view.z;
	view_points[idx] = p_view;
	radii[idx] = my_radius;
	points_xy_image[idx] = point_image;
	// Inverse 2D covariance and opacity neatly pack into one float4
	conic_opacity[idx] = { conic.x, conic.y, conic.z, opacities[idx] * ceof};
	tiles_touched[idx] = (rect_max.y - rect_min.y) * (rect_max.x - rect_min.x);
}


// Perform initial steps for each Gaussian prior to rasterization.
template<int C>
__global__ void filter_preprocessCUDA(int P, int M,
	const float* orig_points,
	const glm::vec3* scales,
	const float scale_modifier,
	const glm::vec4* rotations,
	const float* cov3D_precomp,
	const float* viewmatrix,
	const float* projmatrix,
	const int W, int H,
	const float tan_fovx, float tan_fovy,
	const float focal_x, float focal_y,
	int* radii,
	float* cov3Ds,
	const dim3 grid,
	bool prefiltered)
{
	auto idx = cg::this_grid().thread_rank();
	if (idx >= P)
		return;

	// Initialize radius and touched tiles to 0. If this isn't changed,
	// this Gaussian will not be processed further.
	radii[idx] = 0;

	// Perform near culling, quit if outside.
	float3 p_view;
	if (!in_frustum(idx, orig_points, viewmatrix, projmatrix, prefiltered, p_view))
		return;

	// Transform point by projecting
	float3 p_orig = { orig_points[3 * idx], orig_points[3 * idx + 1], orig_points[3 * idx + 2] };
	float4 p_hom = transformPoint4x4(p_orig, projmatrix);
	float p_w = 1.0f / (p_hom.w + 0.0000001f);
	float3 p_proj = { p_hom.x * p_w, p_hom.y * p_w, p_hom.z * p_w };

	// If 3D covariance matrix is precomputed, use it, otherwise compute
	// from scaling and rotation parameters. 
	const float* cov3D;
	if (cov3D_precomp != nullptr)
	{
		cov3D = cov3D_precomp + idx * 6;
	}
	else
	{
		computeCov3D(scales[idx], scale_modifier, rotations[idx], cov3Ds + idx * 6);
		cov3D = cov3Ds + idx * 6;
	}

	// Compute 2D screen-space covariance matrix
	float3 cov = computeCov2D(p_orig, focal_x, focal_y, tan_fovx, tan_fovy, cov3D, viewmatrix);

	// Invert covariance (EWA algorithm)
	float det = (cov.x * cov.z - cov.y * cov.y);
	if (det == 0.0f)
		return;


	// Compute extent in screen space (by finding eigenvalues of
	// 2D covariance matrix). Use extent to compute a bounding rectangle
	// of screen-space tiles that this Gaussian overlaps with. Quit if
	// rectangle covers 0 tiles. 
	float mid = 0.5f * (cov.x + cov.z);
	float lambda1 = mid + sqrt(max(0.1f, mid * mid - det));
	float lambda2 = mid - sqrt(max(0.1f, mid * mid - det));
	float my_radius = ceil(3.f * sqrt(max(lambda1, lambda2)));
	float2 point_image = { ndc2Pix(p_proj.x, W), ndc2Pix(p_proj.y, H) };
	uint2 rect_min, rect_max;
	getRect(point_image, my_radius, rect_min, rect_max, grid);
	if ((rect_max.x - rect_min.x) * (rect_max.y - rect_min.y) == 0)
		return;


	radii[idx] = my_radius;
	
}

// Main rasterization method. Collaboratively works on one tile per
// block, each thread treats one pixel. Alternates between fetching 
// and rasterizing data.
template <uint32_t CHANNELS, bool COORD, bool DEPTH, bool NORMAL>
__global__ void __launch_bounds__(BLOCK_X * BLOCK_Y)
renderCUDA(
	const uint2* __restrict__ ranges,
	const uint32_t* __restrict__ point_list,
	int W, int H,
	const float* __restrict__ view_points,
	const float2* __restrict__ points_xy_image,
	const float* __restrict__ features,
	const float* __restrict__ ts,
	const float* __restrict__ camera_planes,
	const float2* __restrict__ ray_planes,
	const float3* __restrict__ normals,
	const float4* __restrict__ conic_opacity,
	const float focal_x, const float focal_y,
	float* __restrict__ out_alpha,
	uint32_t* __restrict__ n_contrib,
	const float* __restrict__ bg_color,
	float* __restrict__ out_color,
	float* __restrict__ out_coord,
	float* __restrict__ out_mcoord,
	float* __restrict__ out_normal,
	float* __restrict__ out_depth,
	float* __restrict__ out_mdepth,
	float* __restrict__ accum_coord,
	float* __restrict__ accum_depth,
	float* __restrict__ normal_length)
{
	// Identify current tile and associated min/max pixel range.
	auto block = cg::this_thread_block();
	uint32_t horizontal_blocks = (W + BLOCK_X - 1) / BLOCK_X;
	uint2 pix_min = { block.group_index().x * BLOCK_X, block.group_index().y * BLOCK_Y };
	uint2 pix_max = { min(pix_min.x + BLOCK_X, W), min(pix_min.y + BLOCK_Y , H) };
	uint2 pix = { pix_min.x + block.thread_index().x, pix_min.y + block.thread_index().y };
	uint32_t pix_id = W * pix.y + pix.x;
	float2 pixf = { (float)pix.x, (float)pix.y };
    float2 pixnf = {(pixf.x-W/2.f)/focal_x,(pixf.y-H/2.f)/focal_y};
	float ln = sqrt(pixnf.x*pixnf.x+pixnf.y*pixnf.y+1);

	constexpr bool GEO = DEPTH || COORD || NORMAL;

	// Check if this thread is associated with a valid pixel or outside.
	bool inside = pix.x < W&& pix.y < H;
	// Done threads can help with fetching, but don't rasterize
	bool done = !inside;

	// Load start/end range of IDs to process in bit sorted list.
	uint2 range = ranges[block.group_index().y * horizontal_blocks + block.group_index().x];
	const int rounds = ((range.y - range.x + BLOCK_SIZE - 1) / BLOCK_SIZE);
	int toDo = range.y - range.x;

	// Allocate storage for batches of collectively fetched data.
	__shared__ int collected_id[BLOCK_SIZE];
	__shared__ float2 collected_xy[BLOCK_SIZE];
	__shared__ float4 collected_conic_opacity[BLOCK_SIZE];

    __shared__ float collected_feature[BLOCK_SIZE * CHANNELS];
    __shared__ float collected_camera_plane[BLOCK_SIZE * 6];
	__shared__ float collected_mean3d[BLOCK_SIZE * 3];
	__shared__ float collected_ts[BLOCK_SIZE];
	__shared__ float2 collected_ray_planes[BLOCK_SIZE];
	__shared__ float3 collected_normals[BLOCK_SIZE];

	// Initialize helper variables
	float T = 1.0f;
	uint32_t contributor = 0;
	uint32_t last_contributor = 0;
	float C[CHANNELS] = { 0 };

    uint32_t max_contributor = -1;
    float weight = 0;
	float Coord[3] = { 0 };
	float mCoord[3] = { 0 };
	float Depth = 0;
	float mDepth = 0;
	float Normal[3] = {0};

	// Iterate over batches until all done or range is complete
	for (int i = 0; i < rounds; i++, toDo -= BLOCK_SIZE)
	{
		// End if entire block votes that it is done rasterizing
		int num_done = __syncthreads_count(done);
		if (num_done == BLOCK_SIZE)
			break;

		// Collectively fetch per-Gaussian data from global to shared
		int progress = i * BLOCK_SIZE + block.thread_rank();
		if (range.x + progress < range.y)
		{
			int coll_id = point_list[range.x + progress];
			collected_id[block.thread_rank()] = coll_id;
			collected_xy[block.thread_rank()] = points_xy_image[coll_id];
			collected_conic_opacity[block.thread_rank()] = conic_opacity[coll_id];
		    for(int ch = 0; ch < CHANNELS; ch++)
				collected_feature[ch * BLOCK_SIZE + block.thread_rank()] = features[coll_id * CHANNELS + ch];
			if constexpr (COORD)
			{
				for(int ch = 0; ch < 6; ch++)
					collected_camera_plane[ch * BLOCK_SIZE + block.thread_rank()] = camera_planes[coll_id * 6 + ch];
				for(int ch = 0; ch < 3; ch++)
					collected_mean3d[ch * BLOCK_SIZE + block.thread_rank()] = view_points[coll_id * 3 + ch];
			}
			if constexpr (DEPTH)
			{
				collected_ts[block.thread_rank()] = ts[coll_id];
				collected_ray_planes[block.thread_rank()] = ray_planes[coll_id];
			}
			if constexpr (NORMAL)
			{
				collected_normals[block.thread_rank()] = normals[coll_id];
			}
		}
		block.sync();

		// Iterate over current batch
		for (int j = 0; !done && j < min(BLOCK_SIZE, toDo); j++)
		{
			// Keep track of current position in range
			contributor++;

			// Resample using conic matrix (cf. "Surface 
			// Splatting" by Zwicker et al., 2001)
			float2 xy = collected_xy[j];
			float2 d = { xy.x - pixf.x, xy.y - pixf.y };
			float4 con_o = collected_conic_opacity[j];
			float power = -0.5f * (con_o.x * d.x * d.x + con_o.z * d.y * d.y) - con_o.y * d.x * d.y;
			if (power > 0.0f)
				continue;

			// Eq. (2) from 3D Gaussian splatting paper.
			// Obtain alpha by multiplying with Gaussian opacity
			// and its exponential falloff from mean.
			// Avoid numerical instabilities (see paper appendix). 
			// float det = 
			float alpha = min(0.99f, con_o.w * exp(power));
			if (alpha < 1.0f / 255.0f)
				continue;
			float test_T = T * (1 - alpha);
			if (test_T < 0.0001f)
			{
				done = true;
				continue;
			}

			// Eq. (3) from 3D Gaussian splatting paper.
			for (int ch = 0; ch < CHANNELS; ch++)
				C[ch] += features[collected_id[j] * CHANNELS + ch] * alpha * T;

            const float aT = alpha * T;

            bool before_median = T > 0.5;
			if constexpr (COORD)
			{
				float2 camera_plane0 = {collected_camera_plane[j], collected_camera_plane[j + BLOCK_SIZE]};
				float2 camera_plane1 = {collected_camera_plane[j + BLOCK_SIZE * 2], collected_camera_plane[j + BLOCK_SIZE * 3]};
				float2 camera_plane2 = {collected_camera_plane[j + BLOCK_SIZE * 4], collected_camera_plane[j + BLOCK_SIZE * 5]};
				float coord[3] = {collected_mean3d[j] + camera_plane0.x * d.x + camera_plane0.y * d.y,
									collected_mean3d[j + BLOCK_SIZE] + camera_plane1.x * d.x + camera_plane1.y * d.y,
									collected_mean3d[j + BLOCK_SIZE * 2] + camera_plane2.x * d.x + camera_plane2.y * d.y};
				for(int ch = 0; ch < 3; ch++)
					Coord[ch] += coord[ch] * aT;
				if (before_median){
					for(int ch = 0; ch < 3; ch++)
						mCoord[ch] = coord[ch];
				}
			}
			if constexpr (DEPTH)
			{
				float t_center = collected_ts[j];
				float2 ray_plane = collected_ray_planes[j];
				float t = t_center + (ray_plane.x * d.x + ray_plane.y * d.y);
				Depth += t * aT;
				if (before_median) mDepth = t;
			}

			if constexpr (NORMAL)
			{
				Normal[0] += collected_normals[j].x * aT;
				Normal[1] += collected_normals[j].y * aT;
				Normal[2] += collected_normals[j].z * aT;
			}

			if constexpr (GEO)
			{
				if (before_median)
					max_contributor = contributor;
			}

            weight += aT;
			T = test_T;

			// Keep track of last range entry to update this
			// pixel.
			last_contributor = contributor;
		}
	}

	// All threads that treat valid pixel write out their final
	// rendering data to the frame and auxiliary buffers.
	if (inside)
	{
        n_contrib[pix_id] = last_contributor;
		n_contrib[pix_id + H * W] = max_contributor;
		for (int ch = 0; ch < CHANNELS; ch++)
			out_color[ch * H * W + pix_id] = C[ch] + T * bg_color[ch];
        out_alpha[pix_id] = weight;

        if constexpr (COORD)
		{
			if(last_contributor)
			{
				for (int ch = 0; ch < 3; ch++)
				{
					out_coord[ch * H * W + pix_id] = Coord[ch] / weight;
				}
			}
			else
			{
				for (int ch = 0; ch < 3; ch++)
					out_coord[ch * H * W + pix_id] = 0;
			}
			for (int ch = 0; ch < 3; ch++)
			{
				accum_coord[ch * H * W + pix_id] = Coord[ch];
				out_mcoord[ch * H * W + pix_id] = mCoord[ch];
			}
		}

		if constexpr (DEPTH)
		{
			float depth_ln = Depth/ln;
			accum_depth[pix_id] = depth_ln;
			if(last_contributor)
			{
				out_depth[pix_id] = depth_ln/weight;
			}
			else
			{
				out_depth[pix_id] = 0;
			}
			out_mdepth[pix_id] = mDepth/ln;
		}

		if constexpr (NORMAL)
		{
			if(last_contributor)
			{
				float len_normal = sqrt(Normal[0]*Normal[0]+Normal[1]*Normal[1]+Normal[2]*Normal[2]);
				normal_length[pix_id] = len_normal;
				len_normal = max(len_normal, NORMALIZE_EPS);
				for (int ch = 0; ch < 3; ch++)
					out_normal[ch * H * W + pix_id] = Normal[ch]/len_normal;
			}
			else
			{
				normal_length[pix_id] = 1;
				for (int ch = 0; ch < 3; ch++)
					out_normal[ch * H * W + pix_id] = 0;
			}
		}
	}
}

void FORWARD::render(
	const dim3 grid, dim3 block,
	const uint2* ranges,
	const uint32_t* point_list,
	int W, int H,
	const float* view_points,
	const float2* means2D,
	const float* colors,
	const float* ts,
	const float* camera_planes,
	const float2* ray_planes,
	const float3* normals,
	const float4* conic_opacity,
	const float focal_x, float focal_y,
	float* out_alpha,
	uint32_t* n_contrib,
	const float* bg_color,
	float* out_color,
	float* out_coord,
	float* out_mcoord,
	float* out_normal,
	float* out_depth,
	float* out_mdepth,
	float* accum_coord,
	float* accum_depth,
	float* normal_length,
	bool require_coord,
	bool require_depth)
{
#define RENDER_CUDA_CALL(template_coord, template_depth, template_normal)\
	renderCUDA<NUM_CHANNELS, template_coord, template_depth, template_normal> << <grid, block >>> (ranges,point_list,W, H,view_points,means2D,colors,ts,camera_planes,\
	ray_planes,normals,conic_opacity,focal_x, focal_y,out_alpha,n_contrib,bg_color,out_color,out_coord,out_mcoord,out_normal,out_depth,out_mdepth,accum_coord,accum_depth,normal_length)

    if (require_coord && require_depth)
		RENDER_CUDA_CALL(true, true, true);
	else if (require_coord && !require_depth)
		RENDER_CUDA_CALL(true, false, true);
	else if(!require_coord && require_depth)
		RENDER_CUDA_CALL(false, true, true);
	else
		RENDER_CUDA_CALL(false, false, false);

#undef RENDER_CUDA_CALL
}

void FORWARD::preprocess(int P, int D, int M,
	const float* means3D,
	const glm::vec3* scales,
	const float scale_modifier,
	const glm::vec4* rotations,
	const float* opacities,
	const float* shs,
	bool* clamped,
	const float* cov3D_precomp,
	const float* colors_precomp,
	const float* viewmatrix,
	const float* projmatrix,
	const glm::vec3* cam_pos,
	const int W, int H,
	const float focal_x, float focal_y,
	const float tan_fovx, float tan_fovy,
	int* radii,
	float2* means2D,
	float3* view_points,
	float* depths,
	float* camera_planes,
	float2* ray_planes,
	float* ts,
	float3* normals,
	float* cov3Ds,
	float* rgb,
	float4* conic_opacity,
	const dim3 grid,
	uint32_t* tiles_touched,
	bool prefiltered,
	float* invraycov3Ds,
	bool* condition)
{
	preprocessCUDA<NUM_CHANNELS> << <(P + 255) / 256, 256 >> > (
		P, D, M,
		means3D,
		scales,
		scale_modifier,
		rotations,
		opacities,
		shs,
		clamped,
		cov3D_precomp,
		colors_precomp,
		viewmatrix, 
		projmatrix,
		cam_pos,
		W, H,
		tan_fovx, tan_fovy,
		focal_x, focal_y,
		radii,
		means2D,
		view_points,
		depths,
		camera_planes,
        ray_planes,
        normals,
		cov3Ds,
		rgb,
		conic_opacity,
		grid,
		tiles_touched,
		prefiltered,
		invraycov3Ds,
        ts,
        condition
		);
}


void FORWARD::filter_preprocess(int P, int M,
	const float* means3D,
	const glm::vec3* scales,
	const float scale_modifier,
	const glm::vec4* rotations,
	const float* cov3D_precomp,
	const float* viewmatrix,
	const float* projmatrix,
	const int W, int H,
	const float focal_x, float focal_y,
	const float tan_fovx, float tan_fovy,
	int* radii,
	float* cov3Ds,
	const dim3 grid,
	bool prefiltered)
{

	filter_preprocessCUDA<NUM_CHANNELS> << <(P + 255) / 256, 256 >> > (
		P, M,
		means3D,
		scales,
		scale_modifier,
		rotations,
		cov3D_precomp,
		viewmatrix, 
		projmatrix,
		W, H,
		tan_fovx, tan_fovy,
		focal_x, focal_y,
		radii,
		cov3Ds,
		grid,
		prefiltered
		);
}