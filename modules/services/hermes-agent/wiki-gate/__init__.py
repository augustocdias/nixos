"""Block file-tool writes that break the wiki vault's raw, review and gold tiers."""
from . import gate


def register(ctx):
    settings = gate.load()

    def hook(tool_name=None, args=None, task_id="", **_):
        if tool_name not in gate.WRITE_TOOLS + gate.MEMORY_TOOLS:
            return None
        try:
            from hermes_constants import get_hermes_home, profile_name_for_home

            # A child routed by profile_routes runs under its profile's context-local home override;
            # HERMES_HOME names the gateway process instead.
            profile = profile_name_for_home(get_hermes_home())
            if tool_name in gate.MEMORY_TOOLS:
                reason = gate.memory_writer(settings, profile)
                return {"action": "block", "message": reason} if reason else None
            for path in gate.paths(tool_name, args if isinstance(args, dict) else {}):
                reason = gate.decide(settings, profile, gate.resolve(path, task_id))
                if reason:
                    return {"action": "block", "message": reason}
        except Exception as error:
            return {"action": "block", "message": f"Wiki gate failed closed: {error}"}
        return None

    ctx.register_hook("pre_tool_call", hook)
