public with sharing class ADA_ObjectIndexStore implements ADA_IMetadataIndexStore {
  public List<ADA_Metadata_Index__c> forObject(String objectApiName) {
    if (String.isBlank(objectApiName)) {
      return new List<ADA_Metadata_Index__c>();
    }
    return [
      SELECT
        Id,
        Object_Api_Name__c,
        Component_Type__c,
        Api_Name__c,
        Label__c,
        Description__c,
        Message_Template__c,
        Message_Normalised__c,
        Formula_Masked__c,
        Field_Api_Names__c,
        Active__c,
        Source_Last_Modified__c,
        Indexed_At__c
      FROM ADA_Metadata_Index__c
      WHERE Object_Api_Name__c = :objectApiName
      WITH USER_MODE
      ORDER BY Component_Type__c, Api_Name__c
    ];
  }

  public List<ADA_Metadata_Index__c> forObjectAndType(
    String objectApiName,
    String componentType
  ) {
    List<ADA_Metadata_Index__c> matches = new List<ADA_Metadata_Index__c>();
    if (String.isBlank(componentType)) {
      return matches;
    }
    for (ADA_Metadata_Index__c row : forObject(objectApiName)) {
      if (row.Component_Type__c == componentType) {
        matches.add(row);
      }
    }
    return matches;
  }
}
