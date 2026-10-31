public with sharing class ADA_ExplanationService {
  public class Outcome {
    public ADA_Explanation explanation;
    public String payloadSent;
    public Boolean cached = false;
    public String fallbackReason;
    public Set<String> blockedKinds = new Set<String>();
  }

  public static Outcome explain(
    ADA_Diagnosis diagnosis,
    ADA_PayloadBuilder.Extras extras
  ) {
    ADA_PayloadBuilder.Extras input = extras == null
      ? new ADA_PayloadBuilder.Extras()
      : extras;
    ADA_ILlmProvider provider = ADA_LlmProviderFactory.create();
    Outcome outcome = new Outcome();
    if (provider instanceof ADA_TemplateProvider) {
      outcome.explanation = provider.explain(diagnosis, input);
      return outcome;
    }
    String locale = String.isBlank(input.locale)
      ? UserInfo.getLocale()
      : input.locale;
    Boolean cacheable = String.isBlank(input.userQuestion);
    ADA_ExplanationCache cache = new ADA_ExplanationCache();
    if (cacheable) {
      ADA_Explanation hit = cache.find(diagnosis, locale);
      if (hit != null) {
        outcome.explanation = hit;
        outcome.cached = true;
        return outcome;
      }
    }
    try {
      outcome.explanation = provider.explain(diagnosis, input);
      outcome.payloadSent = provider.lastPayload();
      if (cacheable) {
        cache.store(diagnosis, locale, outcome.explanation);
      }
    } catch (ADA_BlockedRequestException blocked) {
      outcome.blockedKinds = blocked.kinds;
      return fallBack(outcome, diagnosis, input, blocked.getMessage());
    } catch (Exception failure) {
      outcome.payloadSent = provider.lastPayload();
      return fallBack(outcome, diagnosis, input, failure.getMessage());
    }
    return outcome;
  }

  private static Outcome fallBack(
    Outcome outcome,
    ADA_Diagnosis diagnosis,
    ADA_PayloadBuilder.Extras input,
    String reason
  ) {
    outcome.explanation = new ADA_TemplateProvider().explain(diagnosis, input);
    outcome.fallbackReason = reason;
    return outcome;
  }
}
