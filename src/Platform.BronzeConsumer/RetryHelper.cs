using Microsoft.Extensions.Logging;

namespace Platform.BronzeConsumer;

public static class RetryHelper
{
    public static async Task ExecuteAsync(
        Func<Task> action,
        RetryOptions retryOptions,
        ILogger logger,
        string operationName,
        CancellationToken cancellationToken)
    {
        Exception? lastException = null;

        for (var attempt = 1; attempt <= retryOptions.MaxAttempts; attempt++)
        {
            try
            {
                await action();
                return;
            }
            catch (Exception ex) when (attempt < retryOptions.MaxAttempts)
            {
                lastException = ex;

                logger.LogWarning(
                    ex,
                    "Operation {OperationName} failed on attempt {Attempt} of {MaxAttempts}. Retrying after {DelayMilliseconds} ms.",
                    operationName,
                    attempt,
                    retryOptions.MaxAttempts,
                    retryOptions.DelayMilliseconds);

                await Task.Delay(retryOptions.DelayMilliseconds, cancellationToken);
            }
            catch (Exception ex)
            {
                lastException = ex;
                break;
            }
        }

        throw new InvalidOperationException(
            $"Operation '{operationName}' failed after {retryOptions.MaxAttempts} attempts.",
            lastException);
    }
}

