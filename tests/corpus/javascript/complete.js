/** Native JavaScript fixture <&>. */
export class Entry {
  #value = 1_000;

  constructor(name) {
    this.name = name;
  }

  async render(enabled = true) {
    const text = `name=${this.name}\n`;
    await Promise.resolve(text);
    return enabled ? { value: this.#value, text } : null;
  }
}

console.log(new Entry("demo <&>").render(false));
