try {
  List<ADA_MetadataIndexer.WorkItem> pending = new ADA_MetadataIndexer()
    .discover();
  System.debug(LoggingLevel.ERROR, 'ADA_INDEX_OK|discovered, rules and flows to fetch=' + pending.size());
} catch (Exception e) {
  System.debug(LoggingLevel.ERROR, 'ADA_INDEX_FAIL|discover: ' + e.getMessage());
}
