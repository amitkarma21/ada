List<List<String>> cases = new List<List<String>>{
  new List<String>{ 'Opportunity', 'Close date cannot be in the past for an open opportunity.' },
  new List<String>{ 'Opportunity', 'Opportunities over 100,000 need a description.' },
  new List<String>{ 'Case', 'Please choose a reason before closing the case.' }
};
List<String> results = new List<String>();
try {
  for (List<String> item : cases) {
    ADA_Diagnosis diagnosis = ADA_DiagnosisService.diagnose(item[0], item[1]);
    if (diagnosis.errorType != ADA_ErrorType.VALIDATION_RULE) {
      throw new ADA_LlmException('Not diagnosed (is the index built?): ' + item[1]);
    }
    ADA_PayloadBuilder.Extras extras = new ADA_PayloadBuilder.Extras();
    extras.objectLabel = diagnosis.objectApiName;
    // A typed question keeps this run free of cache writes, so every case can call out.
    extras.userQuestion = 'Why was I blocked and what should I do?';
    for (ADA_Metadata_Index__c row : [
      SELECT Formula_Masked__c
      FROM ADA_Metadata_Index__c
      WHERE
        Component_Type__c = :diagnosis.componentType
        AND Object_Api_Name__c = :diagnosis.objectApiName
        AND Api_Name__c = :diagnosis.componentApiName
      LIMIT 1
    ]) {
      extras.conditionFormulaMasked = row.Formula_Masked__c;
    }
    ADA_ExplanationService.Outcome outcome = ADA_ExplanationService.explain(
      diagnosis,
      extras
    );
    if (outcome.explanation.source != 'LLM') {
      throw new ADA_LlmException('Fell back to Template: ' + outcome.fallbackReason);
    }
    results.add(diagnosis.componentApiName + ' => ' + outcome.explanation.summary + ' | steps: ' + String.join(outcome.explanation.fixSteps, ' / '));
  }
  System.debug(LoggingLevel.ERROR, 'ADA_LIVE_OK|' + String.join(results, ' ## '));
} catch (Exception e) {
  System.debug(LoggingLevel.ERROR, 'ADA_LIVE_FAIL|' + e.getMessage());
}
