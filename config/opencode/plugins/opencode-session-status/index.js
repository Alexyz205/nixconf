import { mkdir, readlink, rename, unlink, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { Plugin } from "@opencode/plugin";

const statusDirectory =
  process.env.OPENCODE_STATUS_DIR ||
  join(process.env.HOME || ".", ".local", "state", "opencode", "agent-status");
const statusFile = join(statusDirectory, `${process.pid}.json`);

const eventTypes = [
  "session.status",
  "session.idle",
  "session.created",
  "session.renamed",
  "session.agent.selected",
  "permission.asked",
  "permission.replied",
  "form.created",
  "form.replied",
  "form.cancelled",
];

async function readTty() {
  for (const fd of [0, 1, 2]) {
    try {
      return await readlink(`/proc/self/fd/${fd}`);
    } catch {
      continue;
    }
  }

  return null;
}

function addPending(items, requestID) {
  if (!requestID || items.includes(requestID)) {
    return items;
  }

  return [...items, requestID];
}

function removePending(items, requestID) {
  if (!requestID) {
    return items;
  }

  return items.filter((item) => item !== requestID);
}

function syncInteractionState(state) {
  const hasQuestions = state.pendingQuestions.length > 0;
  const hasPermissions = state.pendingPermissions.length > 0;

  state.awaitingUser = hasQuestions || hasPermissions;
  state.interactionType = hasQuestions
    ? "question"
    : hasPermissions
      ? "permission"
      : null;
}

function deriveState(state) {
  if (state.awaitingUser) {
    return "question";
  }

  if (state.status === "busy" || state.status === "retry") {
    return "busy";
  }

  return "idle";
}

function applyEvent(state, event) {
  const data = event.data ?? event.properties ?? {};

  switch (event.type) {
    case "session.status": {
      state.sessionID = data.sessionID ?? state.sessionID;
      state.status = data.status?.type ?? state.status;
      break;
    }
    case "session.idle": {
      state.sessionID = data.sessionID ?? state.sessionID;
      state.status = "idle";
      state.subagent = null;
      break;
    }
    case "session.created": {
      state.sessionID = data.sessionID ?? state.sessionID;
      if (data.agent) {
        state.agent = data.agent;
      }
      if (data.parentID) {
        state.subagent = data.agent ?? state.subagent;
      } else if (data.title) {
        state.sessionTitle = data.title;
      }
      break;
    }
    case "session.renamed": {
      state.sessionID = data.sessionID ?? state.sessionID;
      if (data.title) {
        state.sessionTitle = data.title;
      }
      break;
    }
    case "session.agent.selected": {
      state.sessionID = data.sessionID ?? state.sessionID;
      if (data.agent) {
        state.agent = data.agent;
      }
      break;
    }
    case "permission.asked": {
      state.sessionID = data.sessionID ?? state.sessionID;
      state.pendingPermissions = addPending(state.pendingPermissions, data.id);
      break;
    }
    case "permission.replied": {
      state.sessionID = data.sessionID ?? state.sessionID;
      state.pendingPermissions = removePending(
        state.pendingPermissions,
        data.requestID,
      );
      break;
    }
    case "form.created": {
      const form = data.form ?? {};
      state.sessionID = form.sessionID ?? state.sessionID;
      state.pendingQuestions = addPending(state.pendingQuestions, form.id);
      break;
    }
    case "form.replied":
    case "form.cancelled": {
      state.sessionID = data.sessionID ?? state.sessionID;
      state.pendingQuestions = removePending(state.pendingQuestions, data.id);
      break;
    }
  }
}

export default Plugin.define({
  id: "nixconf.opencode-session-status",
  async setup(ctx) {
    const state = {
      pid: process.pid,
      directory: ctx.location.directory,
      worktree: ctx.location.project?.canonical ?? null,
      tmuxPane: process.env.TMUX_PANE || null,
      tty: await readTty(),
      sessionID: null,
      sessionTitle: null,
      status: "idle",
      agent: null,
      subagent: null,
      awaitingUser: false,
      interactionType: null,
      pendingQuestions: [],
      pendingPermissions: [],
      startedAt: Date.now(),
      updatedAt: Date.now(),
      state: "idle",
    };

    let persistChain = Promise.resolve();

    const persist = () => {
      state.updatedAt = Date.now();
      state.state = deriveState(state);
      const payload = `${JSON.stringify(state, null, 2)}\n`;

      persistChain = persistChain
        .then(async () => {
          await mkdir(statusDirectory, { recursive: true });
          const tmp = `${statusFile}.${process.pid}.tmp`;
          await writeFile(tmp, payload, "utf8");
          await rename(tmp, statusFile);
        })
        .catch((error) => {
          console.error("[opencode-session-status] failed to persist status", error);
        });

      return persistChain;
    };

    await persist();

    const controller = new AbortController();

    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({
          types: eventTypes,
          signal: controller.signal,
        })) {
          applyEvent(state, event);
          syncInteractionState(state);
          await persist();
        }
      } catch (error) {
        if (!controller.signal.aborted) {
          console.error(
            "[opencode-session-status] event stream failed",
            error,
          );
        }
      }
    })();

    return async () => {
      controller.abort();
      await persistChain;
      await unlink(statusFile).catch((error) => {
        if (error?.code !== "ENOENT") {
          throw error;
        }
      });
    };
  },
});
