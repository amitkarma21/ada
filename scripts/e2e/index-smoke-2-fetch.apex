try {
  ADA_MetadataIndexer indexer = new ADA_MetadataIndexer();
  List<ADA_MetadataIndexer.WorkItem> pending = indexer.discover();
  List<ADA_MetadataIndexer.WorkItem> left = indexer.runChunk(pending, 80);
  System.debug(LoggingLevel.ERROR, 'ADA_INDEX_OK|fetched ' + (pending.size() - left.size()) + ' of ' + pending.size() + ', left=' + left.size());
} catch (Exception e) {
  System.debug(LoggingLevel.ERROR, 'ADA_INDEX_FAIL|fetch: ' + e.getMessage());
}
