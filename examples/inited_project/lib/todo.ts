export type TodoItem = {
  id: string;
  text: string;
  done: boolean;
};

export function addTodo(items: TodoItem[], text: string): TodoItem[] {
  const trimmed = text.trim();
  if (!trimmed) return items;
  const id = `t${Date.now()}`;
  return [{ id, text: trimmed, done: false }, ...items];
}

export function toggleTodo(items: TodoItem[], id: string): TodoItem[] {
  return items.map((t) => (t.id === id ? { ...t, done: !t.done } : t));
}


