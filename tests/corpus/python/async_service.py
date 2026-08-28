from collections.abc import AsyncIterator


class Service:
    async def stream(self, limit: int | None = None) -> AsyncIterator[str]:
        async for item in self.client.items(limit=limit):
            yield item.name
