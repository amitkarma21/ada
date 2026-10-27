public with sharing class ADA_Diagnosis {
  public ADA_ErrorType errorType { get; private set; }
  public Decimal confidence { get; private set; }
  public String objectApiName { get; set; }
  public String componentType { get; set; }
  public String componentApiName { get; set; }
  public String componentLabel { get; set; }
  public String description { get; set; }
  public List<String> fieldApiNames { get; set; }
  public ADA_SuggestedAction suggestedAction { get; set; }

  public ADA_Diagnosis(ADA_ErrorType errorType, Decimal confidence) {
    this.errorType = errorType == null ? ADA_ErrorType.UNKNOWN : errorType;
    this.confidence = clamp(confidence);
    this.fieldApiNames = new List<String>();
    this.suggestedAction = ADA_SuggestedAction.EXPLAIN_ONLY;
  }

  public static ADA_Diagnosis unknown() {
    return new ADA_Diagnosis(ADA_ErrorType.UNKNOWN, 0);
  }

  public Boolean isConfident(Decimal threshold) {
    return errorType != ADA_ErrorType.UNKNOWN && confidence >= threshold;
  }

  private static Decimal clamp(Decimal value) {
    if (value == null || value < 0) {
      return 0;
    }
    return value > 1 ? 1 : value;
  }
}
