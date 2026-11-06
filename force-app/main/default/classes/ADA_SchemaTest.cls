@IsTest
private class ADA_SchemaTest {
  private static final Set<String> ALLOWED_INDEX_FIELDS = new Set<String>{
    'object_api_name__c',
    'component_type__c',
    'api_name__c',
    'label__c',
    'description__c',
    'message_template__c',
    'message_normalised__c',
    'formula_masked__c',
    'field_api_names__c',
    'active__c',
    'source_last_modified__c',
    'indexed_at__c',
    'explanation_json__c',
    'explained_for__c',
    'flow_runs_when__c'
  };

  @IsTest
  static void indexHoldsOnlyMetadataFields() {
    Map<String, Schema.SObjectField> fields = Schema.SObjectType.ADA_Metadata_Index__c.fields.getMap();
    Set<String> custom = new Set<String>();
    for (String name : fields.keySet()) {
      if (name.endsWith('__c')) {
        custom.add(name);
      }
    }
    Assert.areEqual(
      ALLOWED_INDEX_FIELDS,
      custom,
      'Index must hold only the fields listed in ARCHITECTURE section 1'
    );
  }

  @IsTest
  static void indexHasNoRelationshipFields() {
    for (
      Schema.SObjectField field : Schema.SObjectType.ADA_Metadata_Index__c.fields.getMap()
        .values()
    ) {
      Schema.DescribeFieldResult describe = field.getDescribe();
      if (describe.isCustom()) {
        Assert.areEqual(
          0,
          describe.getReferenceTo().size(),
          describe.getName() + ' must not be a lookup'
        );
      }
    }
  }

  @IsTest
  static void idempotencyKeyIsUnique() {
    Schema.DescribeFieldResult key = Schema.SObjectType.ADA_Action_Log__c.fields.Idempotency_Key__c;
    Assert.isTrue(key.isUnique());
  }
}
