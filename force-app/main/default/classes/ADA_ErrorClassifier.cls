public with sharing class ADA_ErrorClassifier {
  public static final Decimal THRESHOLD_FLOOR = 0.6;
  private static final Decimal JUST_BELOW = 0.01;

  private final List<ADA_IMatcher> matchers;
  public final Decimal threshold;

  public ADA_ErrorClassifier(List<ADA_IMatcher> matchers, Decimal threshold) {
    this.matchers = matchers;
    this.threshold = clampThreshold(threshold);
  }

  public static List<ADA_IMatcher> defaultMatchers() {
    return new List<ADA_IMatcher>{
      new ADA_RequiredFieldMatcher(),
      new ADA_ValidationRuleMatcher(),
      new ADA_DuplicateRuleMatcher(),
      new ADA_AccessChecker(),
      new ADA_FlowErrorMatcher(),
      new ADA_ApexErrorMatcher()
    };
  }

  public static Decimal clampThreshold(Decimal value) {
    if (value == null) {
      return 0.8;
    }
    return Math.min(1, Math.max(THRESHOLD_FLOOR, value));
  }

  // The first confident matcher wins. If a second matcher is also confident the evidence
  // is ambiguous, so the winner is held just under the threshold and ADA will not guess.
  public ADA_Diagnosis classify(ADA_ErrorContext context) {
    if (!context.hasMessage() || String.isBlank(context.objectApiName)) {
      return ADA_Diagnosis.unknown();
    }
    List<ADA_Diagnosis> found = new List<ADA_Diagnosis>();
    for (ADA_IMatcher matcher : matchers) {
      ADA_Diagnosis result = matcher.match(context);
      if (result != null) {
        found.add(result);
      }
    }
    List<ADA_Diagnosis> confident = new List<ADA_Diagnosis>();
    for (ADA_Diagnosis result : found) {
      if (result.isConfident(threshold)) {
        confident.add(result);
      }
    }
    if (confident.isEmpty()) {
      return closest(found);
    }
    if (confident.size() > 1) {
      confident[0].capConfidence(threshold - JUST_BELOW);
    }
    return confident[0];
  }

  private static ADA_Diagnosis closest(List<ADA_Diagnosis> found) {
    ADA_Diagnosis best = ADA_Diagnosis.unknown();
    for (ADA_Diagnosis result : found) {
      if (result.confidence > best.confidence) {
        best = result;
      }
    }
    return best;
  }
}
