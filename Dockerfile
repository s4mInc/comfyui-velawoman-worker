# Serverless worker for the v3la woman pipeline.
# Base image speaks the {"input":{"workflow":...}} API the runner uses.
#
# Tag note: release 5.8.7 exists on GitHub but was never pushed to Docker Hub,
# so 5.8.7-base fails to resolve. 5.8.6-base is the newest published base image.
FROM runpod/worker-comfyui:5.8.6-base

# 5.8.6 ships a ComfyUI too old for the krea2 CLIP type that node 106:13 needs.
# Jobs failed validation with: type 'krea2' not in (list of length 23).
# krea2 landed in ComfyUI 0.28.0; 0.29.0 is what worker-comfyui 5.8.7 itself pins.
#
# Done in Python on purpose. Two earlier approaches failed on this image:
#   comfy-cli 1.13.0 `update` has no --version flag        -> exit 2
#   curl/tar are not installed in the base image           -> exit 127
# The interpreter at /comfyui/.venv/bin/python is guaranteed present (ComfyUI runs
# on it) and its stdlib downloads and extracts without any external tool.
#
# requirements.txt is deliberately NOT reinstalled: it pins torch, and replacing the
# CUDA-matched build already in this image would be worse than a missing pure-python
# dependency, which would name itself in the worker log.
#
# The assert is a build-time gate: if the overlay lands a ComfyUI without krea2, the
# build fails here rather than at render time.
RUN /comfyui/.venv/bin/python -c "import urllib.request,tarfile,io,shutil,os,pathlib;u='https://github.com/comfyanonymous/ComfyUI/archive/refs/tags/v0.29.0.tar.gz';t=tarfile.open(fileobj=io.BytesIO(urllib.request.urlopen(u,timeout=600).read()));t.extractall('/tmp/cu');d=os.path.join('/tmp/cu',os.listdir('/tmp/cu')[0]);shutil.copytree(d,'/comfyui',dirs_exist_ok=True);shutil.rmtree('/tmp/cu');s=pathlib.Path('/comfyui/nodes.py').read_text();assert 'krea2' in s,'krea2 missing after overlay';print('overlay ok: ComfyUI 0.29.0, krea2 present')"

# rgthree provides the Power Lora Loader (node 57) and is the ONLY custom pack this
# workflow needs. Installed after the overlay so it lands on the new ComfyUI.
# ComfyUI-Easy-Use was removed: it failed to import here, and its nodes only
# concatenated prompt strings the runner already assembles in Python.
RUN comfy-node-install rgthree-comfy

# No model downloads on purpose: the weights live on the network volume, which
# serverless mounts at /runpod-volume and ComfyUI reads automatically from
# /runpod-volume/models/{unet,clip,vae,loras}.
