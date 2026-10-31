@IsTest
public class ADA_IndexTestSupport {
  public static final String SAME_DATE = '2026-01-01T00:00:00.000+0000';
  public static final String FLOW_SAME_DATE = '2026-02-01T00:00:00.000+0000';
  public static final String NEWER_DATE = '2026-03-01T10:00:00.000+0000';

  public class Router implements HttpCalloutMock {
    public List<Map<String, Object>> rules = new List<Map<String, Object>>();
    public List<Map<String, Object>> flows = new List<Map<String, Object>>();
    public List<Map<String, Object>> triggers = new List<Map<String, Object>>();
    public List<Map<String, Object>> classes = new List<Map<String, Object>>();
    public List<Map<String, Object>> duplicates = new List<Map<String, Object>>();
    public List<Map<String, Object>> entities = new List<Map<String, Object>>();
    public Map<String, Object> metadataById = new Map<String, Object>();
    public Set<String> failingIds = new Set<String>();
    public Boolean unauthorised = false;
    public Integer metadataCalls = 0;
    public Integer totalCalls = 0;

    public HttpResponse respond(HttpRequest request) {
      totalCalls++;
      HttpResponse response = new HttpResponse();
      if (unauthorised) {
        response.setStatusCode(401);
        response.setBody('[]');
        return response;
      }
      String endpoint = request.getEndpoint();
      String soql = EncodingUtil.urlDecode(
        endpoint.substringAfter('?q='),
        'UTF-8'
      );
      if (soql.startsWith('SELECT Id, Metadata FROM')) {
        return metadataResponse(soql);
      }
      response.setStatusCode(200);
      response.setBody(page(listFor(soql)));
      return response;
    }

    private HttpResponse metadataResponse(String soql) {
      metadataCalls++;
      String id = soql.substringAfter('\'').substringBefore('\'');
      HttpResponse response = new HttpResponse();
      if (failingIds.contains(id)) {
        response.setStatusCode(500);
        response.setBody('{}');
        return response;
      }
      response.setStatusCode(200);
      Map<String, Object> metadata = metadataById.containsKey(id)
        ? (Map<String, Object>) metadataById.get(id)
        : new Map<String, Object>{
            'errorConditionFormula' => 'Amount > 5',
            'errorMessage' => 'Amount is too high.'
          };
      response.setBody(
        page(
          new List<Map<String, Object>>{
            new Map<String, Object>{ 'Id' => id, 'Metadata' => metadata }
          }
        )
      );
      return response;
    }

    private List<Map<String, Object>> listFor(String soql) {
      if (soql.contains('FROM FlowDefinitionView')) {
        return flows;
      }
      if (soql.contains('FROM DuplicateRule')) {
        return duplicates;
      }
      if (soql.contains('FROM ValidationRule')) {
        return rules;
      }
      if (soql.contains('FROM ApexTrigger')) {
        return triggers;
      }
      if (soql.contains('FROM ApexClass')) {
        return classes;
      }
      if (soql.contains('FROM EntityDefinition')) {
        return entities;
      }
      return new List<Map<String, Object>>();
    }

    private String page(List<Map<String, Object>> records) {
      return JSON.serialize(
        new Map<String, Object>{ 'done' => true, 'records' => records }
      );
    }
  }

  public static Router install() {
    Router router = new Router();
    Test.setMock(HttpCalloutMock.class, router);
    return router;
  }

  public static String fakeId(Integer index) {
    return '03d' + String.valueOf(100000000000L + index);
  }

  public static Map<String, Object> rule(
    String id,
    String name,
    String objectName,
    String modified
  ) {
    return new Map<String, Object>{
      'Id' => id,
      'ValidationName' => name,
      'NamespacePrefix' => null,
      'Active' => true,
      'EntityDefinition' => new Map<String, Object>{
        'QualifiedApiName' => objectName
      },
      'LastModifiedDate' => modified,
      'Description' => null
    };
  }

  public static Map<String, Object> flow(
    String versionId,
    String apiName,
    String objectName,
    String modified
  ) {
    return new Map<String, Object>{
      'ApiName' => apiName,
      'Label' => apiName,
      'ActiveVersionId' => versionId,
      'TriggerObjectOrEventId' => objectName,
      'LastModifiedDate' => modified
    };
  }

  public static ADA_MetadataIndexer.WorkItem ruleItem(Integer index) {
    ADA_MetadataIndexer.WorkItem item = new ADA_MetadataIndexer.WorkItem();
    item.kind = ADA_MetadataIndexer.VALIDATION_RULE;
    item.sourceId = fakeId(index);
    item.apiName = 'Bulk_Rule_' + index;
    item.objectApiName = 'Opportunity';
    item.label = item.apiName;
    item.active = true;
    item.modified = Datetime.newInstanceGmt(2026, 3, 1, 10, 0, 0);
    return item;
  }

  public static List<ADA_MetadataIndexer.WorkItem> ruleItems(Integer count) {
    List<ADA_MetadataIndexer.WorkItem> items = new List<ADA_MetadataIndexer.WorkItem>();
    for (Integer i = 0; i < count; i++) {
      items.add(ruleItem(i));
    }
    return items;
  }

  public static User createUser(String alias, String permissionSetName) {
    Id profileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1]
    .Id;
    User user = new User(
      Alias = alias,
      Email = alias + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = alias,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = profileId,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = alias + '.' + UserInfo.getOrganizationId() + '@example.com'
    );
    insert user;
    insert new PermissionSetAssignment(
      AssigneeId = user.Id,
      PermissionSetId = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = :permissionSetName
      ]
      .Id
    );
    return user;
  }

  public static void seedIndex() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert new List<ADA_Metadata_Index__c>{
        existing('ValidationRule', 'Case', 'Rule_Same', 1, 1),
        existing('ValidationRule', 'Case', 'Gone_Rule', 1, 1),
        existing('Flow', 'Case', 'Flow_Same', 2, 1),
        existing('Flow', 'Case', 'Flow_Old', 2, 1)
      };
    }
  }

  private static ADA_Metadata_Index__c existing(
    String type,
    String objectName,
    String apiName,
    Integer month,
    Integer day
  ) {
    return new ADA_Metadata_Index__c(
      Component_Type__c = type,
      Object_Api_Name__c = objectName,
      Api_Name__c = apiName,
      Active__c = true,
      Source_Last_Modified__c = Datetime.newInstanceGmt(
        2026,
        month,
        day,
        0,
        0,
        0
      )
    );
  }
}
