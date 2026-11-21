// Terminal title: the session label alone. omp's default title is "π > <label>" plus a
// run-state mark, and herdr shows it verbatim. ctx.ui.setTitle replaces the whole title,
// so the brand and mark go; the working spinner is off while the override is set.
// Lives beside herdr-omp-agent-state.ts, which herdr overwrites on update.
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

type SessionManagerLike = {
	getSessionName?: () => string | undefined;
	onSessionNameChanged?: (listener: () => void) => () => void;
};

type TitleContext = {
	sessionManager?: SessionManagerLike;
	ui?: { setTitle?: (title: string) => void };
};

function applyTitle(ctx: TitleContext): void {
	const label = ctx.sessionManager?.getSessionName?.()?.trim();
	ctx.ui?.setTitle?.(label || "omp");
}

export default function titleLabel(pi: ExtensionAPI): void {
	let unsubscribe: (() => void) | undefined;

	// A rename runs upstream's handler, which clears the title override. Re-apply on the next
	// tick so this runs after that handler, whatever the listener order.
	const attach = (ctx: TitleContext) => {
		unsubscribe?.();
		unsubscribe = ctx.sessionManager?.onSessionNameChanged?.(() => {
			setTimeout(() => applyTitle(ctx), 0);
		});
		applyTitle(ctx);
	};

	pi.on("session_start", (_event: unknown, ctx: TitleContext) => attach(ctx));
	// /new emits session_switch, then the command controller writes the base title. Re-apply on the
	// next tick so the label lands after that write.
	pi.on("session_switch", (_event: unknown, ctx: TitleContext) => {
		attach(ctx);
		setTimeout(() => applyTitle(ctx), 0);
	});
	pi.on("session_shutdown", () => {
		unsubscribe?.();
		unsubscribe = undefined;
	});
	pi.on("agent_start", (_event: unknown, ctx: TitleContext) => applyTitle(ctx));
	pi.on("agent_end", (_event: unknown, ctx: TitleContext) => applyTitle(ctx));
}
