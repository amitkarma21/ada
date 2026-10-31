public with sharing class ADA_MetadataIndexer {
  public static final String VALIDATION_RULE = 'ValidationRule';
  public static final String FLOW = 'Flow';
  public static final String APEX_TRIGGER = 'ApexTrigger';
  public static final String DUPLICATE_RULE = 'DuplicateRule';
  public static final String REQUIRED_FIELD = 'RequiredField';

  private static final Set<String> ALWAYS_INDEXED_OBJECTS = new Set<String>{
    'Account',
    'Contact',
    'Lead',
    'Opportunity',
    'Case'
  };
  private static final Integer CLASS_NAMES_PER_QUERY = 40;
  private static final Integer MAX_CLASS_NAMES = 200;
  private static final Integer FAILURES_BEFORE_ABORT = 3;
  private static final Integer LONG_TEXT = 32768;
  private static final Integer MEDIUM_TEXT = 4000;
  private static final Pattern SAFE_ID = Pattern.compile('[A-Za-z0-9]{15,18}');
  private static final Pattern CUSTOM_OBJECT_ID = Pattern.compile(
    '01I[A-Za-z0-9]{12,15}'
  );

  private static final String RULE_LIST =
    'SELECT Id, ValidationName, NamespacePrefix, Active, EntityDefinition.QualifiedApiName, ' +
    'LastModifiedDate, Description FROM ValidationRule';
  private static final String FLOW_LIST =
    'SELECT ApiName, Label, ActiveVersionId, TriggerObjectOrEventId, LastModifiedDate ' +
    'FROM FlowDefinitionView WHERE IsActive = true AND NamespacePrefix = null ' +
    'AND TriggerType IN (\'RecordBeforeSave\', \'RecordAfterSave\')';
  private static final String TRIGGER_LIST =
    'SELECT Id, Name, TableEnumOrId, Status, LastModifiedDate, Body FROM ApexTrigger ' +
    'WHERE NamespacePrefix = null';
  private static final String DUPLICATE_LIST =
    'SELECT DeveloperName, MasterLabel, SobjectType, IsActive, LastModifiedDate, NamespacePrefix ' +
    'FROM DuplicateRule';

  // One rule or flow whose metadata still has to be fetched. Kept small because the
  // queue of these is carried from one Queueable to the next.
  public class WorkItem {
    public String kind;
    public String sourceId;
    public String apiName;
    public String objectApiName;
    public String label;
    public String description;
    public Boolean active;
    public Datetime modified;
  }

  private class ClassSource {
    public String body;
    public Datetime modified;
  }

  private final ADA_ToolingClient client;

  public ADA_MetadataIndexer() {
    this(new ADA_ToolingClient());
  }

  public ADA_MetadataIndexer(ADA_ToolingClient client) {
    this.client = client;
  }

  // Lists everything (callouts first), writes the rows that need no further callout and
  // removes rows whose source is gone. Returns the rules and flows that changed.
  public List<WorkItem> discover() {
    Map<String, ADA_Metadata_Index__c> existing = loadExisting();
    List<Map<String, Object>> rules = client.query(RULE_LIST);
    List<Map<String, Object>> flows = client.queryData(FLOW_LIST);
    List<Map<String, Object>> triggers = client.query(TRIGGER_LIST);
    Map<String, String> tableNames = resolveTables(triggers);
    Map<String, ClassSource> classes = fetchClasses(triggers);
    List<Map<String, Object>> duplicates = client.queryData(DUPLICATE_LIST);

    Set<String> live = new Set<String>();
    Set<String> objects = new Set<String>(ALWAYS_INDEXED_OBJECTS);
    List<ADA_Metadata_Index__c> writes = new List<ADA_Metadata_Index__c>();
    List<WorkItem> pending = new List<WorkItem>();

    for (Map<String, Object> rule : rules) {
      WorkItem item = ruleItem(rule);
      if (item.objectApiName == null) {
        continue;
      }
      objects.add(item.objectApiName);
      live.add(key(item.kind, item.objectApiName, item.apiName));
      if (changed(existing, item)) {
        pending.add(item);
      }
    }
    for (Map<String, Object> flow : flows) {
      WorkItem item = flowItem(flow);
      if (item == null) {
        continue;
      }
      objects.add(item.objectApiName);
      live.add(key(item.kind, item.objectApiName, item.apiName));
      if (changed(existing, item)) {
        pending.add(item);
      }
    }
    for (Map<String, Object> apexTrigger : triggers) {
      ADA_Metadata_Index__c row = triggerRow(apexTrigger, tableNames, classes);
      objects.add(row.Object_Api_Name__c);
      keepIfChanged(row, existing, live, writes);
    }
    for (Map<String, Object> duplicate : duplicates) {
      ADA_Metadata_Index__c row = duplicateRow(duplicate);
      objects.add(row.Object_Api_Name__c);
      keepIfChanged(row, existing, live, writes);
    }
    for (String objectName : objects) {
      ADA_Metadata_Index__c row = requiredFieldRow(objectName);
      if (row != null) {
        keepIfChanged(row, existing, live, writes);
      }
    }
    save(writes, existing);
    removeStale(existing, live);
    return pending;
  }

  // Fetches the metadata of up to `budget` items (one callout each), writes their rows
  // and returns the items left over for the next transaction.
  public List<WorkItem> runChunk(List<WorkItem> items, Integer budget) {
    List<WorkItem> remaining = new List<WorkItem>();
    if (items == null || items.isEmpty()) {
      return remaining;
    }
    Integer take = Math.max(0, Math.min(budget, items.size()));
    Map<String, ADA_Metadata_Index__c> existing = loadExisting();
    List<ADA_Metadata_Index__c> writes = new List<ADA_Metadata_Index__c>();
    Integer failures = 0;
    ADA_ToolingClient.ToolingException lastFailure;
    for (Integer i = 0; i < take; i++) {
      try {
        writes.add(
          items[i].kind == FLOW ? flowRow(items[i]) : ruleRow(items[i])
        );
      } catch (ADA_ToolingClient.ToolingException e) {
        failures++;
        lastFailure = e;
        if (writes.isEmpty() && failures >= FAILURES_BEFORE_ABORT) {
          break;
        }
      }
    }
    if (writes.isEmpty() && lastFailure != null) {
      throw lastFailure;
    }
    save(writes, existing);
    for (Integer i = take; i < items.size(); i++) {
      remaining.add(items[i]);
    }
    return remaining;
  }

  private static WorkItem ruleItem(Map<String, Object> rule) {
    WorkItem item = new WorkItem();
    item.kind = VALIDATION_RULE;
    item.sourceId = (String) rule.get('Id');
    String namespace = (String) rule.get('NamespacePrefix');
    item.apiName =
      (String.isBlank(namespace) ? '' : namespace + '__') +
      (String) rule.get('ValidationName');
    Map<String, Object> entity = (Map<String, Object>) rule.get(
      'EntityDefinition'
    );
    item.objectApiName = entity == null
      ? null
      : (String) entity.get('QualifiedApiName');
    item.label = (String) rule.get('ValidationName');
    item.description = (String) rule.get('Description');
    item.active = rule.get('Active') == true;
    item.modified = parseDate(rule.get('LastModifiedDate'));
    return item;
  }

  private static WorkItem flowItem(Map<String, Object> definition) {
    String versionId = (String) definition.get('ActiveVersionId');
    String objectName = (String) definition.get('TriggerObjectOrEventId');
    if (
      String.isBlank(versionId) ||
      !SAFE_ID.matcher(versionId).matches() ||
      String.isBlank(objectName)
    ) {
      return null;
    }
    WorkItem item = new WorkItem();
    item.kind = FLOW;
    item.sourceId = versionId;
    item.apiName = (String) definition.get('ApiName');
    item.objectApiName = objectName;
    item.label = (String) definition.get('Label');
    item.active = true;
    item.modified = parseDate(definition.get('LastModifiedDate'));
    return item;
  }

  private ADA_Metadata_Index__c ruleRow(WorkItem item) {
    Map<String, Object> metadata = fetchMetadata(
      'ValidationRule',
      item.sourceId
    );
    String message = (String) metadata.get('errorMessage');
    String masked = ADA_FormulaMasker.mask(
      (String) metadata.get('errorConditionFormula')
    );
    List<String> fields = new List<String>();
    String referenced = ADA_FormulaMasker.referencedFields(masked);
    if (referenced != '') {
      fields.addAll(referenced.split(','));
    }
    String display = (String) metadata.get('errorDisplayField');
    if (!String.isBlank(display) && !fields.contains(display)) {
      fields.add(display);
    }
    ADA_Metadata_Index__c row = baseRow(item);
    row.Message_Template__c = clip(message, LONG_TEXT);
    row.Message_Normalised__c = clip(
      ADA_MessageNormaliser.normalise(message),
      LONG_TEXT
    );
    row.Formula_Masked__c = clip(masked, LONG_TEXT);
    row.Field_Api_Names__c = clip(String.join(fields, ','), MEDIUM_TEXT);
    return row;
  }

  private ADA_Metadata_Index__c flowRow(WorkItem item) {
    Map<String, Object> metadata = fetchMetadata('Flow', item.sourceId);
    List<String> messages = new List<String>();
    List<String> fields = new List<String>();
    Object errors = metadata.get('customErrors');
    if (errors instanceof List<Object>) {
      for (Object error : (List<Object>) errors) {
        Object entries = ((Map<String, Object>) error)
          .get('customErrorMessages');
        if (!(entries instanceof List<Object>)) {
          continue;
        }
        for (Object entry : (List<Object>) entries) {
          Map<String, Object> custom = (Map<String, Object>) entry;
          String text = (String) custom.get('errorMessage');
          if (!String.isBlank(text)) {
            messages.add(text);
          }
          String field = (String) custom.get('fieldSelection');
          if (!String.isBlank(field) && !fields.contains(field)) {
            fields.add(field);
          }
        }
      }
    }
    ADA_Metadata_Index__c row = baseRow(item);
    row.Description__c = clip(
      (String) metadata.get('description'),
      MEDIUM_TEXT
    );
    row.Message_Template__c = clip(String.join(messages, '\n'), LONG_TEXT);
    row.Message_Normalised__c = clip(
      ADA_MessageNormaliser.normaliseLines(String.join(messages, '\n')),
      LONG_TEXT
    );
    row.Field_Api_Names__c = clip(String.join(fields, ','), MEDIUM_TEXT);
    return row;
  }

  private Map<String, Object> fetchMetadata(
    String sobjectName,
    String sourceId
  ) {
    if (String.isBlank(sourceId) || !SAFE_ID.matcher(sourceId).matches()) {
      throw new ADA_ToolingClient.ToolingException(
        'A ' + sobjectName + ' id was missing or malformed.'
      );
    }
    List<Map<String, Object>> found = client.query(
      'SELECT Id, Metadata FROM ' +
        sobjectName +
        ' WHERE Id = \'' +
        sourceId +
        '\''
    );
    if (
      found.isEmpty() ||
      !(found[0].get('Metadata') instanceof Map<String, Object>)
    ) {
      throw new ADA_ToolingClient.ToolingException(
        'No metadata came back for ' + sobjectName + ' ' + sourceId + '.'
      );
    }
    return (Map<String, Object>) found[0].get('Metadata');
  }

  private static ADA_Metadata_Index__c baseRow(WorkItem item) {
    return new ADA_Metadata_Index__c(
      Component_Type__c = item.kind,
      Object_Api_Name__c = item.objectApiName,
      Api_Name__c = item.apiName,
      Label__c = clip(item.label, 255),
      Description__c = clip(item.description, MEDIUM_TEXT),
      Active__c = item.active,
      Source_Last_Modified__c = item.modified,
      Indexed_At__c = System.now()
    );
  }

  private ADA_Metadata_Index__c triggerRow(
    Map<String, Object> apexTrigger,
    Map<String, String> tableNames,
    Map<String, ClassSource> classes
  ) {
    String body = (String) apexTrigger.get('Body');
    String table = (String) apexTrigger.get('TableEnumOrId');
    Datetime modified = parseDate(apexTrigger.get('LastModifiedDate'));
    List<String> messages = ADA_MessageLiterals.fromAddError(body);
    List<String> helpers = new List<String>();
    for (String name : ADA_MessageLiterals.classNames(body)) {
      ClassSource source = classes.get(name.toLowerCase());
      if (source == null) {
        continue;
      }
      helpers.add(name);
      for (String text : ADA_MessageLiterals.fromAddError(source.body)) {
        if (!messages.contains(text)) {
          messages.add(text);
        }
      }
      if (
        source.modified != null &&
        (modified == null ||
        source.modified > modified)
      ) {
        modified = source.modified;
      }
    }
    helpers.sort();
    String joined = String.join(messages, '\n');
    return new ADA_Metadata_Index__c(
      Component_Type__c = APEX_TRIGGER,
      Object_Api_Name__c = tableNames.containsKey(table)
        ? tableNames.get(table)
        : table,
      Api_Name__c = (String) apexTrigger.get('Name'),
      Label__c = (String) apexTrigger.get('Name'),
      Description__c = helpers.isEmpty()
        ? null
        : clip('Calls: ' + String.join(helpers, ', '), MEDIUM_TEXT),
      Active__c = apexTrigger.get('Status') == 'Active',
      Message_Template__c = clip(joined, LONG_TEXT),
      Message_Normalised__c = clip(
        ADA_MessageNormaliser.normaliseLines(joined),
        LONG_TEXT
      ),
      Source_Last_Modified__c = modified,
      Indexed_At__c = System.now()
    );
  }

  private static ADA_Metadata_Index__c duplicateRow(
    Map<String, Object> duplicate
  ) {
    String namespace = (String) duplicate.get('NamespacePrefix');
    return new ADA_Metadata_Index__c(
      Component_Type__c = DUPLICATE_RULE,
      Object_Api_Name__c = (String) duplicate.get('SobjectType'),
      Api_Name__c = (String.isBlank(namespace) ? '' : namespace + '__') +
        (String) duplicate.get('DeveloperName'),
      Label__c = clip((String) duplicate.get('MasterLabel'), 255),
      Active__c = duplicate.get('IsActive') == true,
      Source_Last_Modified__c = parseDate(duplicate.get('LastModifiedDate')),
      Indexed_At__c = System.now()
    );
  }

  // Required fields come from the schema, so no callout is needed. Page-layout
  // requirements are not part of the schema and are not indexed.
  private static ADA_Metadata_Index__c requiredFieldRow(String objectName) {
    Schema.SObjectType type = String.isBlank(objectName)
      ? null
      : Schema.getGlobalDescribe().get(objectName);
    if (type == null) {
      return null;
    }
    List<String> names = new List<String>();
    List<String> labels = new List<String>();
    for (
      Schema.SObjectField field : type.getDescribe().fields.getMap().values()
    ) {
      Schema.DescribeFieldResult describe = field.getDescribe();
      if (
        describe.isCreateable() &&
        !describe.isNillable() &&
        !describe.isDefaultedOnCreate()
      ) {
        names.add(describe.getName());
        labels.add(describe.getLabel());
      }
    }
    names.sort();
    labels.sort();
    return new ADA_Metadata_Index__c(
      Component_Type__c = REQUIRED_FIELD,
      Object_Api_Name__c = type.getDescribe().getName(),
      Api_Name__c = type.getDescribe().getName(),
      Label__c = 'Required fields',
      Description__c = clip(String.join(labels, ', '), MEDIUM_TEXT),
      Field_Api_Names__c = clip(String.join(names, ','), MEDIUM_TEXT),
      Active__c = true,
      Indexed_At__c = System.now()
    );
  }

  private Map<String, String> resolveTables(
    List<Map<String, Object>> triggers
  ) {
    Map<String, String> byShortId = new Map<String, String>();
    List<String> ids = new List<String>();
    for (Map<String, Object> apexTrigger : triggers) {
      String table = (String) apexTrigger.get('TableEnumOrId');
      if (table != null && CUSTOM_OBJECT_ID.matcher(table).matches()) {
        ids.add('\'' + table.substring(0, 15) + '\'');
      }
    }
    Map<String, String> names = new Map<String, String>();
    if (ids.isEmpty()) {
      return names;
    }
    for (
      Map<String, Object> entity : client.query(
        'SELECT DurableId, QualifiedApiName FROM EntityDefinition WHERE DurableId IN (' +
          String.join(ids, ',') +
          ')'
      )
    ) {
      byShortId.put(
        ((String) entity.get('DurableId')).substring(0, 15),
        (String) entity.get('QualifiedApiName')
      );
    }
    for (Map<String, Object> apexTrigger : triggers) {
      String table = (String) apexTrigger.get('TableEnumOrId');
      if (
        table != null &&
        CUSTOM_OBJECT_ID.matcher(table).matches() &&
        byShortId.containsKey(table.substring(0, 15))
      ) {
        names.put(table, byShortId.get(table.substring(0, 15)));
      }
    }
    return names;
  }

  private Map<String, ClassSource> fetchClasses(
    List<Map<String, Object>> triggers
  ) {
    Set<String> wanted = new Set<String>();
    for (Map<String, Object> apexTrigger : triggers) {
      wanted.addAll(
        ADA_MessageLiterals.classNames((String) apexTrigger.get('Body'))
      );
    }
    List<String> names = new List<String>(wanted);
    names.sort();
    Map<String, ClassSource> found = new Map<String, ClassSource>();
    Integer limitIndex = Math.min(names.size(), MAX_CLASS_NAMES);
    for (
      Integer start = 0; start < limitIndex; start += CLASS_NAMES_PER_QUERY
    ) {
      List<String> quoted = new List<String>();
      for (
        Integer i = start;
        i < Math.min(start + CLASS_NAMES_PER_QUERY, limitIndex);
        i++
      ) {
        quoted.add('\'' + String.escapeSingleQuotes(names[i]) + '\'');
      }
      for (
        Map<String, Object> record : client.query(
          'SELECT Name, LastModifiedDate, Body FROM ApexClass WHERE NamespacePrefix = null AND Name IN (' +
            String.join(quoted, ',') +
            ')'
        )
      ) {
        ClassSource source = new ClassSource();
        source.body = (String) record.get('Body');
        source.modified = parseDate(record.get('LastModifiedDate'));
        found.put(((String) record.get('Name')).toLowerCase(), source);
      }
    }
    return found;
  }

  private static Map<String, ADA_Metadata_Index__c> loadExisting() {
    Map<String, ADA_Metadata_Index__c> byKey = new Map<String, ADA_Metadata_Index__c>();
    for (ADA_Metadata_Index__c row : [
      SELECT
        Id,
        Component_Type__c,
        Object_Api_Name__c,
        Api_Name__c,
        Active__c,
        Source_Last_Modified__c,
        Field_Api_Names__c,
        Message_Template__c
      FROM ADA_Metadata_Index__c
      WITH USER_MODE
      LIMIT 50000
    ]) {
      byKey.put(
        key(row.Component_Type__c, row.Object_Api_Name__c, row.Api_Name__c),
        row
      );
    }
    return byKey;
  }

  private static Boolean changed(
    Map<String, ADA_Metadata_Index__c> existing,
    WorkItem item
  ) {
    ADA_Metadata_Index__c row = existing.get(
      key(item.kind, item.objectApiName, item.apiName)
    );
    return row == null ||
      row.Source_Last_Modified__c != item.modified ||
      row.Active__c != item.active;
  }

  private static void keepIfChanged(
    ADA_Metadata_Index__c row,
    Map<String, ADA_Metadata_Index__c> existing,
    Set<String> live,
    List<ADA_Metadata_Index__c> writes
  ) {
    String rowKey = key(
      row.Component_Type__c,
      row.Object_Api_Name__c,
      row.Api_Name__c
    );
    live.add(rowKey);
    ADA_Metadata_Index__c old = existing.get(rowKey);
    Boolean same =
      old != null &&
      old.Source_Last_Modified__c == row.Source_Last_Modified__c &&
      old.Active__c == row.Active__c &&
      sameText(old.Field_Api_Names__c, row.Field_Api_Names__c) &&
      sameText(old.Message_Template__c, row.Message_Template__c);
    if (!same) {
      writes.add(row);
    }
  }

  // An empty text field is stored as null, so the two must compare equal.
  private static Boolean sameText(String stored, String fresh) {
    return String.isBlank(stored) ? String.isBlank(fresh) : stored == fresh;
  }

  private static void save(
    List<ADA_Metadata_Index__c> rows,
    Map<String, ADA_Metadata_Index__c> existing
  ) {
    List<ADA_Metadata_Index__c> inserts = new List<ADA_Metadata_Index__c>();
    List<ADA_Metadata_Index__c> updates = new List<ADA_Metadata_Index__c>();
    for (ADA_Metadata_Index__c row : rows) {
      ADA_Metadata_Index__c old = existing.get(
        key(row.Component_Type__c, row.Object_Api_Name__c, row.Api_Name__c)
      );
      if (old == null) {
        inserts.add(row);
      } else {
        row.Id = old.Id;
        updates.add(row);
      }
    }
    if (!inserts.isEmpty()) {
      Database.insert(inserts, AccessLevel.USER_MODE);
    }
    if (!updates.isEmpty()) {
      Database.update(updates, AccessLevel.USER_MODE);
    }
  }

  private static void removeStale(
    Map<String, ADA_Metadata_Index__c> existing,
    Set<String> live
  ) {
    List<ADA_Metadata_Index__c> stale = new List<ADA_Metadata_Index__c>();
    for (String rowKey : existing.keySet()) {
      if (!live.contains(rowKey)) {
        stale.add(existing.get(rowKey));
      }
    }
    if (!stale.isEmpty()) {
      Database.delete(stale, AccessLevel.USER_MODE);
    }
  }

  private static String key(String type, String objectName, String apiName) {
    return type + '|' + objectName + '|' + apiName;
  }

  private static String clip(String text, Integer max) {
    if (text == null) {
      return null;
    }
    return text.length() > max ? text.substring(0, max) : text;
  }

  private static Datetime parseDate(Object value) {
    if (!(value instanceof String)) {
      return null;
    }
    try {
      return (Datetime) JSON.deserialize(
        '"' + (String) value + '"',
        Datetime.class
      );
    } catch (Exception e) {
      return null;
    }
  }
}
