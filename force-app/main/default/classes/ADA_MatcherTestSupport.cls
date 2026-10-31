@IsTest
public class ADA_MatcherTestSupport {
  public class FakeStore implements ADA_IMetadataIndexStore {
    public List<ADA_Metadata_Index__c> rows = new List<ADA_Metadata_Index__c>();
    public Integer loads = 0;

    public List<ADA_Metadata_Index__c> forObject(String objectApiName) {
      loads++;
      List<ADA_Metadata_Index__c> found = new List<ADA_Metadata_Index__c>();
      for (ADA_Metadata_Index__c row : rows) {
        if (row.Object_Api_Name__c == objectApiName) {
          found.add(row);
        }
      }
      return found;
    }

    public List<ADA_Metadata_Index__c> forObjectAndType(
      String objectApiName,
      String componentType
    ) {
      List<ADA_Metadata_Index__c> found = new List<ADA_Metadata_Index__c>();
      for (ADA_Metadata_Index__c row : forObject(objectApiName)) {
        if (row.Component_Type__c == componentType) {
          found.add(row);
        }
      }
      return found;
    }

    public FakeStore add(ADA_Metadata_Index__c row) {
      rows.add(row);
      return this;
    }
  }

  public static ADA_Metadata_Index__c messageRow(
    String type,
    String objectName,
    String apiName,
    String message
  ) {
    return new ADA_Metadata_Index__c(
      Component_Type__c = type,
      Object_Api_Name__c = objectName,
      Api_Name__c = apiName,
      Label__c = apiName.replace('_', ' '),
      Message_Template__c = message,
      Message_Normalised__c = ADA_MessageNormaliser.normaliseLines(message),
      Active__c = true
    );
  }

  public static ADA_Metadata_Index__c plainRow(
    String type,
    String objectName,
    String apiName,
    String fields
  ) {
    ADA_Metadata_Index__c row = messageRow(type, objectName, apiName, '');
    row.Field_Api_Names__c = fields;
    return row;
  }

  public static ADA_ErrorContext context(
    FakeStore store,
    String objectName,
    String message
  ) {
    return new ADA_ErrorContext(objectName, message, store);
  }

  public class FixedMatcher implements ADA_IMatcher {
    private final ADA_Diagnosis result;

    public FixedMatcher(ADA_Diagnosis result) {
      this.result = result;
    }

    public ADA_Diagnosis match(ADA_ErrorContext context) {
      return result;
    }
  }
}
