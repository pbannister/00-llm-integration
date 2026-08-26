[TASK]
Plan the minerva offline laptop deployment.

Connect to `minerva.lan` over SSH (per the homelab inventory) and discover the hardware: GPU (`lspci | grep -iE 'vga|3d'`, `vulkaninfo --summary` if Vulkan is present), RAM (`free -h`), and disk (`df -h ~`).

Create `documents/11-minerva-travel-plan.md` containing:

- The verified hardware facts with the date.
- The chosen travel model from the candidates in `prompts/features/04-minerva-travel-laptop.md`, with its exact GGUF name, size on disk, expected context, and the rationale.
- The deployment shape: llama.cpp install (backend chosen from the GPU), a single-model or small-router preset on `127.0.0.1:2001`, and the aider and llama.vscode invocations pointing at `http://127.0.0.1:2001/v1`.
- The offline checklist: predownload the GGUF, verify the local server answers, and confirm the tools work with the laptop's network disabled.

Do not modify any file outside `documents/11-minerva-travel-plan.md`.
If minerva is unreachable, create the document with the hardware section marked `unverified` and the model choice deferred, and report the connection failure.

[OUTPUT FORMAT]
Provide a summary of the created document and the verified hardware facts.
No commentary beyond the summary.

[CONTEXT]
Feature requirements: `prompts/features/04-minerva-travel-laptop.md`.
`minerva.lan` is 192.168.8.186, WiFi-attached, with SSH per `homelab/sources/inventory/hosts.yaml`.
The homelab Ansible inventory may be used for provisioning once specs are known.

[FILES]
- `documents/11-minerva-travel-plan.md` — new.
