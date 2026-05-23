import importlib
from . import logic

class KittyPromptBuilder:
    @classmethod
    def INPUT_TYPES(cls):
        d = logic.DEFAULTS
        ml = {"multiline": True}
        return {
            "required": {
                "subject":    ("STRING", {**ml, "default": d["subject"]}),
                "action":     ("STRING", {**ml, "default": d["action"]}),
                "style":      ("STRING", {**ml, "default": d["style"]}),
                "context":    ("STRING", {**ml, "default": d["context"]}),
                "lighting":   ("STRING", {**ml, "default": d["lighting"]}),
                "technical":  ("STRING", {**ml, "default": d["technical"]}),
                "batch_size": ("INT",    {"default": 1, "min": 1, "max": 64}),
                "seed":       ("INT",    {"default": 42, "min": 0, "max": 2**31}),
            }
        }

    RETURN_TYPES = ("STRING",)
    RETURN_NAMES = ("prompt",)
    OUTPUT_IS_LIST = (True,)
    FUNCTION = "run"
    CATEGORY = "prompt"

    def run(self, subject, action, style, context, lighting, technical, batch_size, seed):
        importlib.reload(logic)
        prompts = logic.build_prompts(subject, action, style, context, lighting, technical, seed, batch_size)
        for i, p in enumerate(prompts):
            print(f"[KittyPromptBuilder] [{i}] {p}")
        return (prompts,)


NODE_CLASS_MAPPINGS = {"KittyPromptBuilder": KittyPromptBuilder}
NODE_DISPLAY_NAME_MAPPINGS = {"KittyPromptBuilder": "Kitty Prompt Builder"}
