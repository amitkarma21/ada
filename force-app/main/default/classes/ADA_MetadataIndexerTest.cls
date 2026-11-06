@IsTest
private class ADA_MetadataIndexerTest {
  @TestSetup
  static void setup() {
    ADA_IndexTestSupport.createUser('idxadm', 'ADA_Admin');
    ADA_IndexTestSupport.seedIndex();
  }

  // Test.startTest() commits the set-up data, which a callout would otherwise reject.
  private static User admin() {
    Test.startTest();
    return [SELECT Id FROM User WHERE Alias = 'idxadm' LIMIT 1];
  }

  private static User admin2() {
    return [SELECT Id FROM User WHERE Alias = 'idxadm' LIMIT 1];
  }

  private static ADA_Metadata_Index__c rowOf(String type, String apiName) {
    List<ADA_Metadata_Index__c> rows = [
      SELECT
        Id,
        Object_Api_Name__c,
        Label__c,
        Description__c,
        Active__c,
        Message_Template__c,
        Message_Normalised__c,
        Formula_Masked__c,
        Field_Api_Names__c,
        Flow_Runs_When__c,
        Source_Last_Modified__c
      FROM ADA_Metadata_Index__c
      WHERE Component_Type__c = :type AND Api_Name__c = :apiName
    ];
    return rows.isEmpty() ? null : rows[0];
  }

  private static Map<String, Object> apexTrigger(
    String name,
    String table,
    String body
  ) {
    return new Map<String, Object>{
      'Name' => name,
      'TableEnumOrId' => table,
      'Status' => 'Active',
      'LastModifiedDate' => ADA_IndexTestSupport.NEWER_DATE,
      'Body' => body
    };
  }

  @IsTest
  static void discoverIndexesTriggersHelpersDuplicatesAndRequiredFields() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    router.triggers.add(
      apexTrigger(
        'Case_Guard_Trigger',
        'Case',
        'trigger Case_Guard_Trigger on Case (before insert) { for (Case c : Trigger.new) { c.addError(\'Web cases need an Origin.\'); CaseGuard.check(c); } }'
      )
    );
    router.classes.add(
      new Map<String, Object>{
        'Name' => 'CaseGuard',
        'LastModifiedDate' => '2026-04-01T00:00:00.000+0000',
        'Body' => 'public class CaseGuard { public static void check(Case c) { c.addError(\'Guard says \' + c.Subject); } }'
      }
    );
    router.duplicates.add(
      new Map<String, Object>{
        'DeveloperName' => 'Account_Dup',
        'MasterLabel' => 'Account Dup',
        'SobjectType' => 'Account',
        'IsActive' => true,
        'NamespacePrefix' => null,
        'LastModifiedDate' => ADA_IndexTestSupport.NEWER_DATE
      }
    );
    System.runAs(admin()) {
      List<ADA_MetadataIndexer.WorkItem> pending = new ADA_MetadataIndexer()
        .discover();
      Assert.isTrue(pending.isEmpty());
      ADA_Metadata_Index__c apexTrigger = rowOf(
        'ApexTrigger',
        'Case_Guard_Trigger'
      );
      Assert.areEqual('Case', apexTrigger.Object_Api_Name__c);
      Assert.isTrue(apexTrigger.Active__c);
      Assert.areEqual(
        'Web cases need an Origin.\nGuard says {}',
        apexTrigger.Message_Template__c
      );
      Assert.areEqual(
        'web cases need an origin\nguard says',
        apexTrigger.Message_Normalised__c
      );
      Assert.areEqual('Calls: CaseGuard', apexTrigger.Description__c);
      Assert.areEqual(
        Datetime.newInstanceGmt(2026, 4, 1, 0, 0, 0),
        apexTrigger.Source_Last_Modified__c
      );
      ADA_Metadata_Index__c duplicate = rowOf('DuplicateRule', 'Account_Dup');
      Assert.areEqual('Account', duplicate.Object_Api_Name__c);
      Assert.areEqual('Account Dup', duplicate.Label__c);
      ADA_Metadata_Index__c required = rowOf('RequiredField', 'Opportunity');
      Assert.isTrue(required.Field_Api_Names__c.contains('CloseDate'));
    }
    Assert.areEqual(0, router.metadataCalls);
  }

  @IsTest
  static void aSecondDiscoveryOfUnchangedSourcesWritesNothing() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    router.triggers.add(
      apexTrigger(
        'Quiet_Trigger',
        'Case',
        'trigger Quiet_Trigger on Case (before insert) { }'
      )
    );
    System.runAs(admin()) {
      new ADA_MetadataIndexer().discover();
    }
    Test.stopTest();
    System.runAs(admin2()) {
      Integer before = Limits.getDmlStatements();
      new ADA_MetadataIndexer().discover();
      Assert.areEqual(before, Limits.getDmlStatements());
    }
  }

  @IsTest
  static void discoverQueuesOnlyChangedRulesAndFlowsAndDropsStaleRows() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    router.rules.add(
      ADA_IndexTestSupport.rule(
        ADA_IndexTestSupport.fakeId(1),
        'Rule_Same',
        'Case',
        ADA_IndexTestSupport.SAME_DATE
      )
    );
    router.rules.add(
      ADA_IndexTestSupport.rule(
        ADA_IndexTestSupport.fakeId(2),
        'Rule_New',
        'Case',
        ADA_IndexTestSupport.NEWER_DATE
      )
    );
    router.flows.add(
      ADA_IndexTestSupport.flow(
        '301000000000001',
        'Flow_Same',
        'Case',
        ADA_IndexTestSupport.FLOW_SAME_DATE
      )
    );
    router.flows.add(
      ADA_IndexTestSupport.flow(
        '301000000000002',
        'Flow_Old',
        'Case',
        ADA_IndexTestSupport.NEWER_DATE
      )
    );
    router.flows.add(
      ADA_IndexTestSupport.flow(
        'managed__Flow-1',
        'Managed_Flow',
        'Case',
        ADA_IndexTestSupport.NEWER_DATE
      )
    );
    System.runAs(admin()) {
      List<ADA_MetadataIndexer.WorkItem> pending = new ADA_MetadataIndexer()
        .discover();
      Assert.areEqual(2, pending.size());
      Assert.areEqual('Rule_New', pending[0].apiName);
      Assert.areEqual(ADA_MetadataIndexer.VALIDATION_RULE, pending[0].kind);
      Assert.areEqual('Flow_Old', pending[1].apiName);
      Assert.areEqual('301000000000002', pending[1].sourceId);
      Assert.isNotNull(rowOf('ValidationRule', 'Rule_Same'));
      Assert.isNotNull(rowOf('Flow', 'Flow_Same'));
      Assert.isNull(rowOf('ValidationRule', 'Gone_Rule'));
    }
    Assert.areEqual(0, router.metadataCalls);
  }

  @IsTest
  static void discoverResolvesACustomObjectTriggerTable() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    router.triggers.add(
      apexTrigger(
        'Thing_Trigger',
        '01Iak0000012345AAA',
        'trigger Thing_Trigger on Thing__c (before insert) {}'
      )
    );
    router.entities.add(
      new Map<String, Object>{
        'DurableId' => '01Iak0000012345',
        'QualifiedApiName' => 'Thing__c'
      }
    );
    System.runAs(admin()) {
      new ADA_MetadataIndexer().discover();
      Assert.areEqual(
        'Thing__c',
        rowOf('ApexTrigger', 'Thing_Trigger').Object_Api_Name__c
      );
    }
  }

  @IsTest
  static void aFailedListingKeepsEveryExistingRow() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    router.unauthorised = true;
    System.runAs(admin()) {
      try {
        new ADA_MetadataIndexer().discover();
        Assert.fail('Expected a ToolingException');
      } catch (ADA_ToolingClient.ToolingException e) {
        Assert.isTrue(e.getMessage().contains('refused'));
      }
      Assert.areEqual(4, [SELECT COUNT() FROM ADA_Metadata_Index__c]);
    }
  }

  @IsTest
  static void aFlowRowStoredBeforeTheOutlineExistedIsQueuedAgain() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    router.flows.add(
      ADA_IndexTestSupport.flow(
        '301000000000001',
        'Flow_Same',
        'Case',
        ADA_IndexTestSupport.FLOW_SAME_DATE
      )
    );
    ADA_Metadata_Index__c row = rowOf('Flow', 'Flow_Same');
    row.Flow_Runs_When__c = null;
    update row;
    System.runAs(admin()) {
      List<ADA_MetadataIndexer.WorkItem> pending = new ADA_MetadataIndexer()
        .discover();
      Assert.areEqual(1, pending.size());
      Assert.areEqual('Flow_Same', pending[0].apiName);
    }
  }

  @IsTest
  static void runChunkMasksTheFormulaAndNeverStoresLiterals() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    String ruleId = ADA_IndexTestSupport.fakeId(7);
    router.metadataById.put(
      ruleId,
      new Map<String, Object>{
        'errorConditionFormula' => 'AND(Name = \'Acme Pty Ltd\', OwnerId = \'005000000000001AAA\', CloseDate < TODAY())',
        'errorMessage' => 'Close date cannot be in the past.',
        'errorDisplayField' => 'CloseDate'
      }
    );
    router.metadataById.put(
      '301000000000009',
      new Map<String, Object>{
        'description' => 'Escalation guard',
        'start' => new Map<String, Object>{
          'triggerType' => 'RecordBeforeSave',
          'recordTriggerType' => 'Update',
          'filterLogic' => 'and',
          'filters' => new List<Object>{
            new Map<String, Object>{
              'field' => 'IsEscalated',
              'operator' => 'EqualTo',
              'value' => new Map<String, Object>{ 'booleanValue' => true }
            },
            new Map<String, Object>{
              'field' => 'Subject',
              'operator' => 'EqualTo',
              'value' => new Map<String, Object>{
                'stringValue' => 'Jo Citizen refund'
              }
            }
          }
        },
        'customErrors' => new List<Object>{
          new Map<String, Object>{
            'customErrorMessages' => new List<Object>{
              new Map<String, Object>{
                'errorMessage' => 'Escalated cases must have High priority.',
                'fieldSelection' => 'Priority',
                'isFieldError' => true
              }
            }
          }
        }
      }
    );
    ADA_MetadataIndexer.WorkItem rule = ADA_IndexTestSupport.ruleItem(7);
    ADA_MetadataIndexer.WorkItem flow = new ADA_MetadataIndexer.WorkItem();
    flow.kind = ADA_MetadataIndexer.FLOW;
    flow.sourceId = '301000000000009';
    flow.apiName = 'Escalation_Flow';
    flow.objectApiName = 'Case';
    flow.label = 'Escalation';
    flow.active = true;
    flow.modified = Datetime.newInstanceGmt(2026, 3, 1, 10, 0, 0);
    System.runAs(admin()) {
      List<ADA_MetadataIndexer.WorkItem> left = new ADA_MetadataIndexer()
        .runChunk(new List<ADA_MetadataIndexer.WorkItem>{ rule, flow }, 10);
      Assert.isTrue(left.isEmpty());
      ADA_Metadata_Index__c ruleRow = rowOf('ValidationRule', 'Bulk_Rule_7');
      Assert.areEqual(
        'AND(Name = \'TEXT_1\', OwnerId = \'ID_1\', CloseDate < TODAY())',
        ruleRow.Formula_Masked__c
      );
      Assert.areEqual('Name,OwnerId,CloseDate', ruleRow.Field_Api_Names__c);
      Assert.areEqual(
        'close date cannot be in the past',
        ruleRow.Message_Normalised__c
      );
      Assert.areEqual('Opportunity', ruleRow.Object_Api_Name__c);
      ADA_Metadata_Index__c flowRow = rowOf('Flow', 'Escalation_Flow');
      Assert.areEqual(
        'Escalated cases must have High priority.',
        flowRow.Message_Template__c
      );
      Assert.areEqual('Priority', flowRow.Field_Api_Names__c);
      Assert.areEqual('Escalation guard', flowRow.Description__c);
      Assert.areEqual(
        'before a record is saved (when it is updated)',
        flowRow.Flow_Runs_When__c
      );
      Assert.areEqual(
        'IsEscalated = TRUE && Subject = \'TEXT_1\'',
        flowRow.Formula_Masked__c
      );
      for (ADA_Metadata_Index__c row : [
        SELECT Formula_Masked__c, Message_Template__c, Description__c
        FROM ADA_Metadata_Index__c
      ]) {
        String all = '' + row.Formula_Masked__c + row.Message_Template__c;
        Assert.isFalse(all.contains('Acme'));
        Assert.isFalse(all.contains('005000000000001'));
      }
    }
  }

  @IsTest
  static void runChunkUpdatesAnExistingRowInPlace() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    ADA_MetadataIndexer.WorkItem item = ADA_IndexTestSupport.ruleItem(3);
    item.apiName = 'Rule_Same';
    item.objectApiName = 'Case';
    System.runAs(admin()) {
      Id before = rowOf('ValidationRule', 'Rule_Same').Id;
      new ADA_MetadataIndexer()
        .runChunk(new List<ADA_MetadataIndexer.WorkItem>{ item }, 5);
      Assert.areEqual(
        1,
        [
          SELECT COUNT()
          FROM ADA_Metadata_Index__c
          WHERE Api_Name__c = 'Rule_Same'
        ]
      );
      ADA_Metadata_Index__c after = rowOf('ValidationRule', 'Rule_Same');
      Assert.areEqual(before, after.Id);
      Assert.areEqual('Amount is too high.', after.Message_Template__c);
    }
    Assert.areEqual(1, router.metadataCalls);
  }

  @IsTest
  static void runChunkNeverSpendsMoreThanItsBudget() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    List<ADA_MetadataIndexer.WorkItem> items = ADA_IndexTestSupport.ruleItems(
      150
    );
    System.runAs(admin()) {
      Integer before = Limits.getCallouts();
      List<ADA_MetadataIndexer.WorkItem> left = new ADA_MetadataIndexer()
        .runChunk(items, 70);
      Assert.areEqual(70, Limits.getCallouts() - before);
      Assert.areEqual(80, left.size());
      Assert.areEqual('Bulk_Rule_70', left[0].apiName);
      Assert.areEqual(
        70,
        [
          SELECT COUNT()
          FROM ADA_Metadata_Index__c
          WHERE Api_Name__c LIKE 'Bulk_Rule_%'
        ]
      );
    }
    Assert.areEqual(70, router.metadataCalls);
  }

  @IsTest
  static void aBrokenItemIsSkippedAndTheRestAreIndexed() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    router.failingIds.add(ADA_IndexTestSupport.fakeId(1));
    System.runAs(admin()) {
      List<ADA_MetadataIndexer.WorkItem> left = new ADA_MetadataIndexer()
        .runChunk(ADA_IndexTestSupport.ruleItems(3), 10);
      Assert.isTrue(left.isEmpty());
      Assert.isNotNull(rowOf('ValidationRule', 'Bulk_Rule_0'));
      Assert.isNull(rowOf('ValidationRule', 'Bulk_Rule_1'));
      Assert.isNotNull(rowOf('ValidationRule', 'Bulk_Rule_2'));
    }
  }

  @IsTest
  static void aChunkWhereEverythingFailsStopsEarlyAndThrows() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    router.unauthorised = true;
    System.runAs(admin()) {
      try {
        new ADA_MetadataIndexer()
          .runChunk(ADA_IndexTestSupport.ruleItems(20), 20);
        Assert.fail('Expected a ToolingException');
      } catch (ADA_ToolingClient.ToolingException e) {
        Assert.isTrue(e.getMessage().contains('refused'));
      }
    }
    Assert.areEqual(3, router.totalCalls);
  }

  @IsTest
  static void anItemWithoutAValidIdFailsWithoutACallout() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    ADA_MetadataIndexer.WorkItem item = ADA_IndexTestSupport.ruleItem(1);
    item.sourceId = '0\' OR Id != \'';
    System.runAs(admin()) {
      try {
        new ADA_MetadataIndexer()
          .runChunk(new List<ADA_MetadataIndexer.WorkItem>{ item }, 5);
        Assert.fail('Expected a ToolingException');
      } catch (ADA_ToolingClient.ToolingException e) {
        Assert.isTrue(e.getMessage().contains('malformed'));
      }
    }
    Assert.areEqual(0, router.totalCalls);
  }

  @IsTest
  static void emptyWorkIsANoOp() {
    ADA_IndexTestSupport.install();
    System.runAs(admin()) {
      Assert.isTrue(new ADA_MetadataIndexer().runChunk(null, 5).isEmpty());
      Assert.isTrue(
        new ADA_MetadataIndexer()
          .runChunk(new List<ADA_MetadataIndexer.WorkItem>(), 5)
          .isEmpty()
      );
    }
  }
}
