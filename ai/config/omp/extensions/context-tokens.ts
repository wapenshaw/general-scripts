// Status line: context used against the window ("300k/1M"), shown through the `status`
// segment placed right after the context bar. omp's own context_pct/context_total segments
// only show the percentage and the window size, never the tokens used.
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

type ContextUsage = { tokens: number; contextWindow: number };

type StatusContext = {
	getContextUsage?: () => ContextUsage | undefined;
	ui?: { setStatus?: (key: string, text: string | undefined) => void };
};

function compact(n: number): string {
	if (n < 1000) return String(Math.round(n));
	if (n < 1_000_000) return `${Math.round(n / 1000)}k`;
	return `${Number((n / 1_000_000).toFixed(1))}M`;
}

function update(ctx: StatusContext): void {
	const usage = ctx.getContextUsage?.();
	const text = usage && usage.contextWindow > 0 ? `${compact(usage.tokens)}/${compact(usage.contextWindow)}` : undefined;
	ctx.ui?.setStatus?.("context-tokens", text);
}

export default function contextTokens(pi: ExtensionAPI): void {
	// Turns grow the context; compaction, /tree, /branch and /clear shrink it without one.
	const events = [
		"session_start",
		"session_switch",
		"session_branch",
		"session_tree",
		"session_compact",
		"session_clear",
		"turn_end",
		"message_end",
		"agent_end",
	] as const;
	for (const event of events) {
		pi.on(event, (_event: unknown, ctx: StatusContext) => update(ctx));
	}
}
