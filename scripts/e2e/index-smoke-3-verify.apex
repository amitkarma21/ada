try {
  Map<String, Set<String>> expected = new Map<String, Set<String>>{
    'ValidationRule' => new Set<String>{
      'ADA_Demo_CloseDate_Future',
      'ADA_Demo_Large_Deal_Description',
      'ADA_Demo_Close_Reason'
    },
    'Flow' => new Set<String>{ 'ADA_Demo_Case_Escalation' },
    'ApexTrigger' => new Set<String>{ 'ADA_Demo_CaseTrigger' },
    'DuplicateRule' => new Set<String>{ 'ADA_Demo_Account_Duplicate' },
    'RequiredField' => new Set<String>{ 'Account', 'Case', 'Opportunity' }
  };
  Map<String, Set<String>> found = new Map<String, Set<String>>();
  List<String> problems = new List<String>();
  Pattern leaked = Pattern.compile('\'(?!(TEXT|ID)_[0-9]+\')[^\']*\'');
  for (ADA_Metadata_Index__c row : [
    SELECT Component_Type__c, Api_Name__c, Formula_Masked__c, Message_Template__c
    FROM ADA_Metadata_Index__c
    WITH USER_MODE
    LIMIT 50000
  ]) {
    if (!found.containsKey(row.Component_Type__c)) {
      found.put(row.Component_Type__c, new Set<String>());
    }
    found.get(row.Component_Type__c).add(row.Api_Name__c);
    if (row.Formula_Masked__c != null && leaked.matcher(row.Formula_Masked__c).find()) {
      problems.add('literal left in formula of ' + row.Api_Name__c);
    }
    if (row.Component_Type__c == 'ValidationRule' && row.Api_Name__c.startsWith('ADA_Demo') && String.isBlank(row.Message_Template__c)) {
      problems.add('no message for ' + row.Api_Name__c);
    }
  }
  for (String type : expected.keySet()) {
    for (String name : expected.get(type)) {
      if (!found.containsKey(type) || !found.get(type).contains(name)) {
        problems.add('missing ' + type + ' ' + name);
      }
    }
  }
  List<ADA_MetadataIndexer.WorkItem> again = new ADA_MetadataIndexer().discover();
  if (!again.isEmpty()) {
    problems.add('a second pass still wants ' + again.size() + ' fetches');
  }
  if (problems.isEmpty()) {
    System.debug(LoggingLevel.ERROR, 'ADA_INDEX_OK|all demo components indexed, second pass idle');
  } else {
    System.debug(LoggingLevel.ERROR, 'ADA_INDEX_FAIL|' + String.join(problems, '; '));
  }
} catch (Exception e) {
  System.debug(LoggingLevel.ERROR, 'ADA_INDEX_FAIL|verify: ' + e.getMessage());
}
