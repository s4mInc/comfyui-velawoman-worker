# Serverless worker for the v3la woman pipeline.
# Base image speaks the {"input":{"workflow":...}} API the runner uses.
#
# Tag note: release 5.8.7 exists on GitHub but was never pushed to Docker Hub,
# so 5.8.7-base fails to resolve. 5.8.6-base is the newest published base image.
FROM runpod/worker-comfyui:5.8.6-base

# ---------------------------------------------------------------------------
# 1. ComfyUI 0.29.0 — 5.8.6 ships one too old for the krea2 CLIP type that node
#    106:13 needs (it offered 23 types; jobs failed "krea2 not in list").
#
#    Done in Python because two other routes fail on THIS image:
#      comfy-cli 1.13.0 `update` has no --version flag   -> exit 2
#      curl and tar are not installed                    -> exit 127
#    /comfyui/.venv/bin/python is guaranteed present (ComfyUI runs on it).
#
#    requirements.txt is deliberately NOT reinstalled: it pins torch, and replacing
#    the CUDA-matched build here would be worse than a missing pure-python dep.
#    The assert gates the build so a bad overlay fails here, not at render time.
RUN /comfyui/.venv/bin/python -c "import urllib.request,tarfile,io,shutil,os,pathlib;u='https://github.com/comfyanonymous/ComfyUI/archive/refs/tags/v0.29.0.tar.gz';t=tarfile.open(fileobj=io.BytesIO(urllib.request.urlopen(u,timeout=600).read()));t.extractall('/tmp/cu');d=os.path.join('/tmp/cu',os.listdir('/tmp/cu')[0]);shutil.copytree(d,'/comfyui',dirs_exist_ok=True);shutil.rmtree('/tmp/cu');s=pathlib.Path('/comfyui/nodes.py').read_text();assert 'krea2' in s,'krea2 missing after overlay';print('overlay ok: ComfyUI 0.29.0, krea2 present')"

# ---------------------------------------------------------------------------
# 2. comfy-kitchen — required to LOAD the fp8 checkpoint. That file stores weights
#    as comfy_quant (U8) + weight_scale (F32) + F8_E4M3, and comfy/quant_ops.py
#    guards its whole layout registry behind `import comfy_kitchen`, logging
#    "fp8 and fp4 support will not be available" when absent. Without it the fp8
#    model fails in UNETLoader with "'NoneType' object has no attribute 'Params'".
#    The bf16 checkpoint never touches this path, which is why it worked already.
#
#    Installed into every venv present: ComfyUI is launched from /opt/venv while
#    comfy-cli builds into /comfyui/.venv, and the two are mirrored, not shared.
RUN for V in /opt/venv /comfyui/.venv; do \
      if [ -x "$V/bin/python" ]; then "$V/bin/python" -m pip install --no-cache-dir comfy-kitchen; fi; \
    done

# ---------------------------------------------------------------------------
# 3. rgthree provides the Power Lora Loader (node 57) and is the ONLY custom node
#    pack this workflow needs. Installed last so it lands on the new ComfyUI.
#    ComfyUI-Easy-Use was removed: it failed to import here, and its nodes only
#    concatenated prompt strings the runner already assembles in Python.
RUN comfy-node-install rgthree-comfy

# Weights live on the network volume, mounted at /runpod-volume on serverless and
# read automatically from /runpod-volume/models/{unet,clip,vae,loras}.
