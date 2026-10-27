public interface ADA_IMetadataIndexStore {
  List<ADA_Metadata_Index__c> forObject(String objectApiName);
  List<ADA_Metadata_Index__c> forObjectAndType(
    String objectApiName,
    String componentType
  );
}
