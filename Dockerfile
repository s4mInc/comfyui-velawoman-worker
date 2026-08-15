# Serverless worker for the v3la woman pipeline.
# Base image speaks the {"input":{"workflow":...}} API the runner uses.
#
# Tag note: GitHub release 5.8.7 exists but was never pushed to Docker Hub, so
# 5.8.7-base fails to resolve. 5.8.6-base is the newest published base image.
# Pinned deliberately, not :latest - a silent ComfyUI bump can change sampler
# behaviour and break reproducibility of already-approved images.
FROM runpod/worker-comfyui:5.8.6-base

# The only two custom node packs this workflow needs:
#   rgthree-comfy    -> Power Lora Loader             (node 57)
#   comfyui-easy-use -> easy positive / promptConcat  (nodes 95-99)
RUN comfy-node-install rgthree-comfy comfyui-easy-use

# No model downloads on purpose: all 36.7GB live on the network volume, which
# serverless mounts at /runpod-volume and ComfyUI reads automatically from
# /runpod-volume/models/{unet,clip,vae,loras}.
