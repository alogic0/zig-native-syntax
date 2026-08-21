"""Native Python highlighting fixture <&>."""

from pathlib import Path

@dataclass
class Entry:
    name: str
    enabled: bool = True

    def render(self, count: int = 1_000) -> str:
        raw = r"raw\n"
        return f"{self.name}: {count}\n"

print(Entry("demo", False).render(1.5e2))  # comment
