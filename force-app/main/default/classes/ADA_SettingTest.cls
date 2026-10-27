@IsTest
private class ADA_SettingTest {
  @IsTest
  static void defaultRecordShipsWithTemplateProvider() {
    ADA_Setting__mdt setting = ADA_Setting__mdt.getInstance('Default');
    Assert.isNotNull(
      setting,
      'Default setting record must ship with the package'
    );
    Assert.areEqual('Template', setting.LLM_Provider__c);
    Assert.areEqual(0.8, setting.Confidence_Threshold__c);
    Assert.areEqual(false, setting.ADO_Enabled__c);
    Assert.areEqual(false, setting.ServiceNow_Enabled__c);
    Assert.areEqual('Bug', setting.ADO_Work_Item_Type__c);
  }
}
