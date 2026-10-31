public with sharing class ADA_ErrorContext {
  private static final Integer MAX_MESSAGE_LENGTH = 4000;

  public final String objectApiName;
  public final String rawMessage;
  public final String normalisedMessage;
  private final ADA_IMetadataIndexStore store;
  private Map<String, List<ADA_Metadata_Index__c>> rowsByType;

  public ADA_ErrorContext(
    String objectApiName,
    String message,
    ADA_IMetadataIndexStore store
  ) {
    this.objectApiName = objectApiName;
    this.store = store;
    String text = message == null ? '' : message;
    this.rawMessage = text.abbreviate(MAX_MESSAGE_LENGTH);
    this.normalisedMessage = ADA_MessageNormaliser.normalise(this.rawMessage);
  }

  public Boolean hasMessage() {
    return normalisedMessage != '';
  }

  public List<ADA_Metadata_Index__c> rows(String componentType) {
    load();
    List<ADA_Metadata_Index__c> found = rowsByType.get(componentType);
    return found == null ? new List<ADA_Metadata_Index__c>() : found;
  }

  public List<ADA_Metadata_Index__c> activeRows(String componentType) {
    List<ADA_Metadata_Index__c> active = new List<ADA_Metadata_Index__c>();
    for (ADA_Metadata_Index__c row : rows(componentType)) {
      if (row.Active__c == true) {
        active.add(row);
      }
    }
    return active;
  }

  private void load() {
    if (rowsByType != null) {
      return;
    }
    rowsByType = new Map<String, List<ADA_Metadata_Index__c>>();
    if (String.isBlank(objectApiName)) {
      return;
    }
    for (ADA_Metadata_Index__c row : store.forObject(objectApiName)) {
      if (!rowsByType.containsKey(row.Component_Type__c)) {
        rowsByType.put(
          row.Component_Type__c,
          new List<ADA_Metadata_Index__c>()
        );
      }
      rowsByType.get(row.Component_Type__c).add(row);
    }
  }
}
