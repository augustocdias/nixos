import { div } from "gpui-kit";
import { v_flex } from "gpui-base";

// Labels survive Core recovery; only a live reporter's lease may reach the UI.
export function activity(terminal, now = Date.now()) {
  if (terminal?.state !== "live") return null;
  try {
    const data = JSON.parse(terminal.labels?.["nix.activity"] ?? "null");
    if (data?.version !== 1 || !Number.isFinite(data.expires) || data.expires <= now) return null;
    if (terminal.program?.key !== data.agent) return null;
    const tokens = data.tokens;
    if (!tokens || ["agent", "title", "todo", "sub1", "sub2", "sub3", "submore"].some(k => typeof tokens[k] !== "string" || tokens[k].length > 80)) return null;
    return tokens;
  } catch {
    return null;
  }
}

export function activityRows(data, address, t) {
  if (!data) return [];
  const lines = [
    ["title", data.title],
    ["todo", data.todo],
    ...["sub1", "sub2", "sub3"].map(k => [k, data[k] ? `Running: ${data[k]}` : ""]),
    ["submore", data.submore ? `More running: ${data.submore}` : ""],
  ].filter(([, value]) => value);
  if (!lines.length) return [];
  return [v_flex().id(`activity-${address}`).pl(33).pr(8).pb(5).gap(2).flex_none()
    .children(lines.map(([key, text]) => div().id(`activity-${address}-${key}`)
      .pl(key.startsWith("sub") ? 10 : 0).text_size(11.5).text_color(t.muted)
      .truncate().tooltip(text).child(text)))];
}
