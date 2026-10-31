public with sharing class ADA_DuplicateRuleMatcher implements ADA_IMatcher {
  public static final Decimal CODED = 0.95;
  public static final Decimal WORDED = 0.9;
  public static final Decimal NO_RULE_INDEXED = 0.6;

  private static final List<String> WORDINGS = new List<String>{
    'use one of these records',
    'creating a duplicate record'
  };

  public ADA_Diagnosis match(ADA_ErrorContext context) {
    if (!context.hasMessage()) {
      return null;
    }
    Decimal signal = signalStrength(context);
    if (signal == 0) {
      return null;
    }
    List<ADA_Metadata_Index__c> rules = context.activeRows(
      ADA_MetadataIndexer.DUPLICATE_RULE
    );
    ADA_Diagnosis diagnosis = new ADA_Diagnosis(
      ADA_ErrorType.DUPLICATE_RULE,
      rules.isEmpty() ? NO_RULE_INDEXED : signal
    );
    diagnosis.objectApiName = context.objectApiName;
    diagnosis.componentType = ADA_MetadataIndexer.DUPLICATE_RULE;
    if (rules.size() == 1) {
      diagnosis.componentApiName = rules[0].Api_Name__c;
      diagnosis.componentLabel = rules[0].Label__c;
      diagnosis.description = rules[0].Description__c;
    }
    return diagnosis;
  }

  private static Decimal signalStrength(ADA_ErrorContext context) {
    if (context.rawMessage.containsIgnoreCase('DUPLICATES_DETECTED')) {
      return CODED;
    }
    for (String wording : WORDINGS) {
      if (context.normalisedMessage.contains(wording)) {
        return WORDED;
      }
    }
    return 0;
  }
}
