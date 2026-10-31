public with sharing class ADA_DiagnosisService {
  @TestVisible
  private static Decimal thresholdOverride;

  public static Decimal threshold() {
    Decimal configured = thresholdOverride;
    if (configured == null) {
      ADA_Setting__mdt setting = ADA_Setting__mdt.getInstance('Default');
      configured = setting == null ? null : setting.Confidence_Threshold__c;
    }
    return ADA_ErrorClassifier.clampThreshold(configured);
  }

  public static ADA_Diagnosis diagnose(String objectApiName, String message) {
    return diagnose(objectApiName, message, new ADA_ObjectIndexStore());
  }

  public static ADA_Diagnosis diagnose(
    String objectApiName,
    String message,
    ADA_IMetadataIndexStore store
  ) {
    ADA_ErrorClassifier classifier = new ADA_ErrorClassifier(
      ADA_ErrorClassifier.defaultMatchers(),
      threshold()
    );
    return classifier.classify(
      new ADA_ErrorContext(objectApiName, message, store)
    );
  }

  // Used by the golden-set runner: no DML, no callouts.
  public static Map<String, Object> diagnoseForHarness(
    String objectApiName,
    String message
  ) {
    Integer started = Limits.getCpuTime();
    ADA_Diagnosis diagnosis = diagnose(objectApiName, message);
    return new Map<String, Object>{
      'type' => diagnosis.errorType.name(),
      'componentApiName' => diagnosis.componentApiName,
      'confidence' => diagnosis.confidence,
      'threshold' => threshold(),
      'cpuMs' => Limits.getCpuTime() - started
    };
  }
}
