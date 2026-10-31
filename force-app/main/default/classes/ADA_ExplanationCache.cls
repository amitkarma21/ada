public with sharing class ADA_ExplanationCache {
  public ADA_Explanation find(ADA_Diagnosis diagnosis, String locale) {
    ADA_Metadata_Index__c row = row(diagnosis);
    if (
      row == null ||
      row.Source_Last_Modified__c == null ||
      row.Explained_For__c != row.Source_Last_Modified__c ||
      String.isBlank(row.Explanation_Json__c)
    ) {
      return null;
    }
    try {
      Map<String, Object> stored = (Map<String, Object>) JSON.deserializeUntyped(
        row.Explanation_Json__c
      );
      if (stored.get('locale') != locale) {
        return null;
      }
      ADA_Explanation explanation = ADA_LlmResponseValidator.fromContent(
        JSON.serialize(stored.get('answer'))
      );
      return explanation;
    } catch (Exception e) {
      return null;
    }
  }

  // The text is built from metadata only and is the same for every user. End users cannot edit
  // the index, so the write runs in the Writer class below, and only touches the two cache fields.
  public void store(
    ADA_Diagnosis diagnosis,
    String locale,
    ADA_Explanation explanation
  ) {
    ADA_Metadata_Index__c row = row(diagnosis);
    if (row == null || row.Source_Last_Modified__c == null) {
      return;
    }
    Map<String, Object> answer = new Map<String, Object>{
      'explanation' => explanation.summary,
      'fixSteps' => explanation.fixSteps,
      'suggestedAction' => actionName(explanation.suggestedAction)
    };
    Map<String, Object> stored = new Map<String, Object>{
      'locale' => locale,
      'answer' => answer
    };
    new Writer()
      .save(row.Id, JSON.serialize(stored), row.Source_Last_Modified__c);
  }

  private static String actionName(ADA_SuggestedAction action) {
    if (action == ADA_SuggestedAction.RAISE_WORK_ITEM) {
      return 'RAISE_BUG';
    }
    if (action == ADA_SuggestedAction.REQUEST_ACCESS) {
      return 'REQUEST_ACCESS';
    }
    return 'NONE';
  }

  private static ADA_Metadata_Index__c row(ADA_Diagnosis diagnosis) {
    if (
      diagnosis == null ||
      String.isBlank(diagnosis.componentType) ||
      String.isBlank(diagnosis.objectApiName) ||
      String.isBlank(diagnosis.componentApiName)
    ) {
      return null;
    }
    List<ADA_Metadata_Index__c> rows = [
      SELECT Id, Source_Last_Modified__c, Explained_For__c, Explanation_Json__c
      FROM ADA_Metadata_Index__c
      WHERE
        Component_Type__c = :diagnosis.componentType
        AND Object_Api_Name__c = :diagnosis.objectApiName
        AND Api_Name__c = :diagnosis.componentApiName
      WITH USER_MODE
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0];
  }

  private without sharing class Writer {
    public void save(Id rowId, String json, Datetime explainedFor) {
      Database.update(
        new ADA_Metadata_Index__c(
          Id = rowId,
          Explanation_Json__c = json,
          Explained_For__c = explainedFor
        ),
        false,
        AccessLevel.SYSTEM_MODE
      );
    }
  }
}
