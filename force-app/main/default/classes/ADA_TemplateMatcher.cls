public virtual with sharing class ADA_TemplateMatcher implements ADA_IMatcher {
  public static final Decimal FLOOR = 0.6;
  public static final Decimal TIE_MARGIN = 0.05;
  public static final Decimal TIE_CONFIDENCE = 0.5;

  private final ADA_ErrorType errorType;
  private final String componentType;

  public ADA_TemplateMatcher(ADA_ErrorType errorType, String componentType) {
    this.errorType = errorType;
    this.componentType = componentType;
  }

  public ADA_Diagnosis match(ADA_ErrorContext context) {
    if (!context.hasMessage()) {
      return null;
    }
    ADA_Metadata_Index__c best;
    Decimal bestScore = 0;
    Decimal secondScore = 0;
    for (ADA_Metadata_Index__c row : context.activeRows(componentType)) {
      Decimal score = ADA_TextMatch.scoreRow(context.normalisedMessage, row);
      if (score > bestScore) {
        secondScore = bestScore;
        bestScore = score;
        best = row;
      } else if (score > secondScore) {
        secondScore = score;
      }
    }
    if (best == null || bestScore < FLOOR) {
      return null;
    }
    Boolean tied = secondScore >= FLOOR && bestScore - secondScore < TIE_MARGIN;
    return describe(
      best,
      context.objectApiName,
      tied ? Math.min(bestScore, TIE_CONFIDENCE) : bestScore
    );
  }

  private ADA_Diagnosis describe(
    ADA_Metadata_Index__c row,
    String objectApiName,
    Decimal confidence
  ) {
    ADA_Diagnosis diagnosis = new ADA_Diagnosis(errorType, confidence);
    diagnosis.objectApiName = objectApiName;
    diagnosis.componentType = componentType;
    diagnosis.componentApiName = row.Api_Name__c;
    diagnosis.componentLabel = row.Label__c;
    diagnosis.description = row.Description__c;
    if (!String.isBlank(row.Field_Api_Names__c)) {
      for (String field : row.Field_Api_Names__c.split(',')) {
        if (!String.isBlank(field)) {
          diagnosis.fieldApiNames.add(field.trim());
        }
      }
    }
    return diagnosis;
  }
}
