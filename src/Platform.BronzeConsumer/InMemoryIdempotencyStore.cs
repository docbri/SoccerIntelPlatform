using System.Collections.Concurrent;

namespace Platform.BronzeConsumer;

public sealed class InMemoryIdempotencyStore : IIdempotencyStore
{
    private readonly ConcurrentDictionary<string, byte> _seen = new();

    public bool HasSeen(string key)
    {
        return _seen.ContainsKey(key);
    }

    public void MarkSeen(string key)
    {
        _seen.TryAdd(key, 0);
    }
}

