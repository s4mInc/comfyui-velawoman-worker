# Serverless worker for the v3la woman pipeline.
# Base image speaks the {"input":{"workflow":...}} API the runner uses.
#
# Tag note: release 5.8.7 exists on GitHub but was never pushed to Docker Hub,
# so 5.8.7-base fails to resolve. 5.8.6-base is the newest published base image.
FROM runpod/worker-comfyui:5.8.6-base

# 5.8.6 ships a ComfyUI too old for the krea2 CLIP type that node 106:13 needs.
# Every job failed validation with:
#   Node 106:13  type: 'krea2' not in (list of length 23)
# krea2 landed in ComfyUI 0.28.0; 0.29.0 is what worker-comfyui 5.8.7 itself pins,
# so it is the known-good target. Pinned, not latest, to keep renders reproducible.
#
# Why overlay the source instead of using comfy-cli: this image pins comfy-cli
# 1.13.0, whose `update` takes only a positional [all|comfy|cli] and has no
# --version flag, so it exits 2. Overlaying the released tarball needs neither
# comfy-cli nor git.
#
# requirements.txt is deliberately NOT reinstalled: it lists torch, and replacing
# the CUDA-matched build already in this image would be far worse than a missing
# pure-python dependency, which would name itself in the worker log.
RUN curl -fsSL https://github.com/comfyanonymous/ComfyUI/archive/refs/tags/v0.29.0.tar.gz -o /tmp/comfy.tgz \
 && tar xzf /tmp/comfy.tgz -C /comfyui --strip-components=1 \
 && rm -f /tmp/comfy.tgz \
 && grep -c krea2 /comfyui/nodes.py

# rgthree provides the Power Lora Loader (node 57) and is the ONLY custom pack this
# workflow needs. Installed after the overlay so it lands on the new ComfyUI.
# ComfyUI-Easy-Use was removed: it failed to import here, and its nodes only
# concatenated prompt strings the runner already assembles in Python.
RUN comfy-node-install rgthree-comfy

# No model downloads on purpose: all 36.7GB live on the network volume, which
# serverless mounts at /runpod-volume and ComfyUI reads automatically from
# /runpod-volume/models/{unet,clip,vae,loras}.
