@IsTest
private class ADA_PermissionsTest {
  @TestSetup
  static void setup() {
    Id profileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1]
    .Id;
    List<User> users = new List<User>();
    for (String alias : new List<String>{ 'adau1', 'adau2', 'adaadm' }) {
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
    Map<String, Id> permSets = new Map<String, Id>();
    for (PermissionSet ps : [
      SELECT Id, Name
      FROM PermissionSet
      WHERE Name IN ('ADA_User', 'ADA_Admin')
    ]) {
      permSets.put(ps.Name, ps.Id);
    }
    List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
    for (User u : users) {
      String name = u.Alias == 'adaadm' ? 'ADA_Admin' : 'ADA_User';
      assignments.add(
        new PermissionSetAssignment(
          AssigneeId = u.Id,
          PermissionSetId = permSets.get(name)
        )
      );
    }
    insert assignments;
  }

  private static User userByAlias(String alias) {
    return [SELECT Id FROM User WHERE Alias = :alias LIMIT 1];
  }

  private static ADA_Action_Log__c newLog(String key) {
    return new ADA_Action_Log__c(
      Step__c = 'Diagnose',
      Error_Type__c = 'UNKNOWN',
      Idempotency_Key__c = key
    );
  }

  @IsTest
  static void userCreatesAndReadsOwnLogAndRequest() {
    System.runAs(userByAlias('adau1')) {
      Database.insert(newLog('k-own'), AccessLevel.USER_MODE);
      ADA_Access_Request__c request = new ADA_Access_Request__c(
        Permission_Set_Group__c = 'Some_Group',
        Justification__c = 'Need it'
      );
      Database.insert(request, AccessLevel.USER_MODE);
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM ADA_Action_Log__c WITH USER_MODE]
      );
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM ADA_Access_Request__c WITH USER_MODE]
      );
      Assert.areEqual(
        'Draft',
        [SELECT Status__c FROM ADA_Access_Request__c WITH USER_MODE LIMIT 1]
        .Status__c
      );
    }
  }

  @IsTest
  static void userCannotSeeOtherUsersLogsOrRequests() {
    System.runAs(userByAlias('adau1')) {
      Database.insert(newLog('k-u1'), AccessLevel.USER_MODE);
      Database.insert(
        new ADA_Access_Request__c(Permission_Set_Group__c = 'Some_Group'),
        AccessLevel.USER_MODE
      );
    }
    System.runAs(userByAlias('adau2')) {
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM ADA_Action_Log__c WITH USER_MODE]
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM ADA_Access_Request__c WITH USER_MODE]
      );
    }
  }

  @IsTest
  static void userCannotEditLogsOrApprovalFields() {
    System.runAs(userByAlias('adau1')) {
      Assert.isFalse(Schema.SObjectType.ADA_Action_Log__c.isUpdateable());
      Assert.isFalse(Schema.SObjectType.ADA_Action_Log__c.isDeletable());
      Assert.isFalse(
        Schema.SObjectType.ADA_Access_Request__c.fields.Status__c.isUpdateable()
      );
      Assert.isFalse(
        Schema.SObjectType.ADA_Access_Request__c.fields.Approver__c.isUpdateable()
      );
      Assert.isFalse(
        Schema.SObjectType.ADA_Access_Request__c.fields.ServiceNow_Number__c.isUpdateable()
      );
      Assert.isFalse(Schema.SObjectType.ADA_Access_Request__c.isDeletable());
    }
  }

  @IsTest
  static void userCannotWriteIndexOrSeeSettings() {
    System.runAs(userByAlias('adau1')) {
      Assert.isTrue(Schema.SObjectType.ADA_Metadata_Index__c.isAccessible());
      Assert.isFalse(Schema.SObjectType.ADA_Metadata_Index__c.isCreateable());
      Assert.isFalse(Schema.SObjectType.ADA_Metadata_Index__c.isUpdateable());
      Assert.isFalse(Schema.SObjectType.ADA_Metadata_Index__c.isDeletable());
      Assert.isFalse(Schema.SObjectType.ADA_Setting__mdt.isAccessible());
      Assert.isFalse(Schema.SObjectType.ADA_Pii_Pattern__mdt.isAccessible());
      Assert.isFalse(
        Schema.SObjectType.ADA_Allowed_Permission__mdt.isAccessible()
      );
    }
  }

  @IsTest
  static void userInsertingIndexRowIsDenied() {
    System.runAs(userByAlias('adau1')) {
      try {
        Database.insert(
          new ADA_Metadata_Index__c(
            Name = 'x',
            Object_Api_Name__c = 'Opportunity'
          ),
          AccessLevel.USER_MODE
        );
        Assert.fail('Insert into the index must be denied for ADA_User');
      } catch (System.TypeException e) {
        Assert.isTrue(e.getMessage().contains('not allowed'));
      }
    }
  }

  @IsTest
  static void adminSeesEverythingAndManagesIt() {
    System.runAs(userByAlias('adau1')) {
      Database.insert(newLog('k-for-admin'), AccessLevel.USER_MODE);
    }
    System.runAs(userByAlias('adaadm')) {
      Assert.isTrue(
        Schema.SObjectType.ADA_Setting__mdt.isAccessible(),
        'setting accessible'
      );
      Assert.isTrue(
        Schema.SObjectType.ADA_Pii_Pattern__mdt.isAccessible(),
        'pii accessible'
      );
      Assert.isTrue(
        Schema.SObjectType.ADA_Allowed_Permission__mdt.isAccessible(),
        'allowed accessible'
      );
      Assert.isTrue(
        Schema.SObjectType.ADA_Metadata_Index__c.isCreateable(),
        'index createable'
      );
      Assert.isTrue(
        Schema.SObjectType.ADA_Access_Request__c.fields.Status__c.isUpdateable(),
        'status updateable'
      );
      List<ADA_Action_Log__c> logs = [
        SELECT Id
        FROM ADA_Action_Log__c
        WITH USER_MODE
      ];
      Assert.areEqual(1, logs.size(), 'admin sees user log');
      Database.delete(logs, AccessLevel.USER_MODE);
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM ADA_Action_Log__c WITH USER_MODE],
        'log deleted'
      );
    }
  }

  @IsTest
  static void duplicateIdempotencyKeyIsRejected() {
    System.runAs(userByAlias('adau1')) {
      Database.insert(newLog('k-dup'), AccessLevel.USER_MODE);
      Database.SaveResult result = Database.insert(
        newLog('k-dup'),
        false,
        AccessLevel.USER_MODE
      );
      Assert.isFalse(result.isSuccess());
    }
  }
}
