import type { Plugin } from "@opencode-ai/plugin"
export default (async ({ client }) => {
  return {
    "tool.execute.after": async (input, output) => {
      // auto log token usage after each tool for maximal observability
      // no-op, placeholder for context-analysis maximal
    }
  }
}) satisfies Plugin
