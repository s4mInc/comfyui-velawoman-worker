# Serverless worker for the v3la woman pipeline.
# Base image speaks the {"input":{"workflow":...}} API the runner uses.
#
# Tag note: release 5.8.7 exists on GitHub but was never pushed to Docker Hub,
# so 5.8.7-base fails to resolve. 5.8.6-base is the newest published base image.
FROM runpod/worker-comfyui:5.8.6-base

# 5.8.6 predates ComfyUI's krea2 CLIP type: its CLIPLoader offers 23 types and the
# workflow's node 106:13 needs "krea2", so every job failed validation with
# "type: 'krea2' not in (list of length 23)". krea2 landed in ComfyUI 0.28.0.
# 0.29.0 is the version worker-comfyui 5.8.7 itself pins, so it is the known-good
# target. Pinned rather than 'latest' to keep renders reproducible.
RUN /usr/bin/yes | comfy --workspace /comfyui update comfy --version 0.29.0

# rgthree provides the Power Lora Loader (node 57) and is the ONLY custom pack
# this workflow needs. ComfyUI-Easy-Use was removed: it failed to import in this
# image, and its nodes only concatenated prompt strings that the runner already
# assembles in Python before dispatch.
RUN comfy-node-install rgthree-comfy

# No model downloads on purpose: all 36.7GB live on the network volume, which
# serverless mounts at /runpod-volume and ComfyUI reads automatically from
# /runpod-volume/models/{unet,clip,vae,loras}.
