import { describe, expect, it, vi } from "vitest";
import { addTodo, toggleTodo } from "./todo";

describe("todo domain", () => {
  it("addTodo ignores blank input", () => {
    const items = [{ id: "t1", text: "hello", done: false }];
    expect(addTodo(items, "   ")).toEqual(items);
  });

  it("addTodo prepends a new item when text is non-empty", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2025-01-01T00:00:00.000Z"));
    const items = [{ id: "t1", text: "hello", done: false }];
    const next = addTodo(items, " world ");
    expect(next[0]).toEqual({ id: "t1735689600000", text: "world", done: false });
    expect(next).toHaveLength(2);
    vi.useRealTimers();
  });

  it("toggleTodo flips done for matching id", () => {
    const items = [
      { id: "a", text: "one", done: false },
      { id: "b", text: "two", done: true }
    ];
    expect(toggleTodo(items, "a")).toEqual([
      { id: "a", text: "one", done: true },
      { id: "b", text: "two", done: true }
    ]);
  });
});


