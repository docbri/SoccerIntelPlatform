using Platform.Shared.Contracts;

namespace Platform.BronzeConsumer;

public static class IngestionEnvelopeValidator
{
    public static EnvelopeValidationResult Validate(IngestionEnvelope envelope)
    {
        var errors = new List<string>();

        if (string.IsNullOrWhiteSpace(envelope.SchemaVersion))
        {
            errors.Add("SchemaVersion is required.");
        }

        if (string.IsNullOrWhiteSpace(envelope.Source))
        {
            errors.Add("Source is required.");
        }

        if (string.IsNullOrWhiteSpace(envelope.EntityType))
        {
            errors.Add("EntityType is required.");
        }

        if (envelope.LeagueId <= 0)
        {
            errors.Add("LeagueId must be greater than zero.");
        }

        if (envelope.Season <= 0)
        {
            errors.Add("Season must be greater than zero.");
        }

        if (string.IsNullOrWhiteSpace(envelope.CorrelationId))
        {
            errors.Add("CorrelationId is required.");
        }

        if (string.IsNullOrWhiteSpace(envelope.Endpoint))
        {
            errors.Add("Endpoint is required.");
        }

        if (string.IsNullOrWhiteSpace(envelope.RequestKey))
        {
            errors.Add("RequestKey is required.");
        }

        if (string.IsNullOrWhiteSpace(envelope.SourceEntityId))
        {
            errors.Add("SourceEntityId is required.");
        }

        if (string.IsNullOrWhiteSpace(envelope.PayloadJson))
        {
            errors.Add("PayloadJson is required.");
        }

        return errors.Count == 0
            ? EnvelopeValidationResult.Valid()
            : EnvelopeValidationResult.Invalid(errors.ToArray());
    }
}

