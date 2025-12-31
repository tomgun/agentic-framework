import styles from "./TodoItemRow.module.css";
import type { TodoItem } from "../lib/todo";

export function TodoItemRow({ todo, onToggle }: { todo: TodoItem; onToggle: () => void }) {
  return (
    <div className={styles.row} data-done={todo.done ? "true" : "false"}>
      <button className={styles.toggle} type="button" onClick={onToggle} aria-label={`Toggle ${todo.text}`}>
        <span className={styles.box} aria-hidden="true" />
      </button>
      <div className={styles.text} title={todo.text}>
        {todo.text}
      </div>
      <div className={styles.state}>{todo.done ? "Done" : "Todo"}</div>
    </div>
  );
}


