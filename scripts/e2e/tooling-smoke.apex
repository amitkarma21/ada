List<String> expected = new List<String>{
  'ADA_Demo_CloseDate_Future',
  'ADA_Demo_Close_Reason',
  'ADA_Demo_Large_Deal_Description'
};
try {
  List<Map<String, Object>> rows = new ADA_ToolingClient()
    .query(
      'SELECT Id, ValidationName FROM ValidationRule WHERE EntityDefinition.QualifiedApiName = \'Opportunity\''
    );
  Set<String> found = new Set<String>();
  for (Map<String, Object> row : rows) {
    found.add((String) row.get('ValidationName'));
  }
  List<String> missing = new List<String>();
  for (String name : expected) {
    if (!found.contains(name)) {
      missing.add(name);
    }
  }
  List<String> names = new List<String>(found);
  names.sort();
  if (missing.isEmpty()) {
    System.debug(LoggingLevel.ERROR, 'ADA_TOOLING_OK|' + String.join(names, ','));
  } else {
    System.debug(LoggingLevel.ERROR, 'ADA_TOOLING_FAIL|missing ' + String.join(missing, ','));
  }
} catch (Exception e) {
  System.debug(LoggingLevel.ERROR, 'ADA_TOOLING_FAIL|' + e.getMessage());
}
