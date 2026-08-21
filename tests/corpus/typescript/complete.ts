/** Native TypeScript fixture <&>. */
export interface Entry<T extends object> {
  readonly value: T;
  enabled?: boolean;
}

export type Result<T> = Promise<T | null>;

export class Renderer<T extends object> implements Entry<T> {
  constructor(public readonly value: T, public enabled = true) {
    this.enabled = enabled;
  }

  async render(count: number = 1_000): Promise<string> {
    return `${count}: ${String(this.value)}\n`;
  }
}
