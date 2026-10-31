@IsTest
private class ADA_ObjectIndexStoreTest {
  @TestSetup
  static void setup() {
    Id profileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1]
    .Id;
    List<User> users = new List<User>();
    for (String alias : new List<String>{ 'idxrd', 'idxno' }) {
      users.add(
        new User(
          Alias = alias,
          Email = alias + '@example.com',
          EmailEncodingKey = 'UTF-8',
          LastName = alias,
          LanguageLocaleKey = 'en_US',
          LocaleSidKey = 'en_US',
          ProfileId = profileId,
          TimeZoneSidKey = 'America/Los_Angeles',
          Username = alias + '.' + UserInfo.getOrganizationId() + '@example.com'
        )
      );
    }
    insert users;
    insert new PermissionSetAssignment(
      AssigneeId = users[0].Id,
      PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'ADA_User']
      .Id
    );
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert new List<ADA_Metadata_Index__c>{
        row('Case', 'ValidationRule', 'Rule_B'),
        row('Case', 'ValidationRule', 'Rule_A'),
        row('Case', 'Flow', 'Flow_A'),
        row('Opportunity', 'ValidationRule', 'Rule_C')
      };
    }
  }

  private static ADA_Metadata_Index__c row(
    String objectName,
    String type,
    String apiName
  ) {
    return new ADA_Metadata_Index__c(
      Object_Api_Name__c = objectName,
      Component_Type__c = type,
      Api_Name__c = apiName,
      Active__c = true
    );
  }

  private static User userByAlias(String alias) {
    return [SELECT Id FROM User WHERE Alias = :alias LIMIT 1];
  }

  @IsTest
  static void returnsOnlyTheRequestedObjectOrderedByPicklistTypeThenName() {
    System.runAs(userByAlias('idxrd')) {
      List<ADA_Metadata_Index__c> rows = new ADA_ObjectIndexStore()
        .forObject('Case');
      Assert.areEqual(3, rows.size());
      Assert.areEqual('Rule_A', rows[0].Api_Name__c);
      Assert.areEqual('Rule_B', rows[1].Api_Name__c);
      Assert.areEqual('Flow_A', rows[2].Api_Name__c);
    }
  }

  @IsTest
  static void filtersByComponentType() {
    System.runAs(userByAlias('idxrd')) {
      List<ADA_Metadata_Index__c> rows = new ADA_ObjectIndexStore()
        .forObjectAndType('Case', 'ValidationRule');
      Assert.areEqual(2, rows.size());
      Assert.areEqual('Rule_A', rows[0].Api_Name__c);
    }
  }

  @IsTest
  static void blankOrUnknownObjectGivesNoRows() {
    System.runAs(userByAlias('idxrd')) {
      ADA_ObjectIndexStore store = new ADA_ObjectIndexStore();
      Assert.isTrue(store.forObject(null).isEmpty());
      Assert.isTrue(store.forObject('').isEmpty());
      Assert.isTrue(store.forObject('Lead').isEmpty());
      Assert.isTrue(store.forObjectAndType('Case', null).isEmpty());
    }
  }

  @IsTest
  static void aUserWithoutThePermissionSetCannotRead() {
    System.runAs(userByAlias('idxno')) {
      try {
        new ADA_ObjectIndexStore().forObject('Case');
        Assert.fail('Expected a user mode query failure');
      } catch (System.QueryException e) {
        Assert.isNotNull(e.getMessage());
      }
    }
  }
}
