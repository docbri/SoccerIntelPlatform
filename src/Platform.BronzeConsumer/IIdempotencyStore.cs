namespace Platform.BronzeConsumer;

public interface IIdempotencyStore
{
    bool HasSeen(string key);
    void MarkSeen(string key);
}

