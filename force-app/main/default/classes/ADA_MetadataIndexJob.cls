public with sharing class ADA_MetadataIndexJob implements Queueable, Database.AllowsCallouts {
  public static final String SCHEDULE_NAME = 'ADA metadata index (nightly)';
  public static final String NIGHTLY_CRON = '0 0 2 * * ?';

  public interface Enqueuer {
    Id enqueue(Queueable job);
  }

  public class SystemEnqueuer implements Enqueuer {
    public Id enqueue(Queueable job) {
      return System.enqueueJob(job);
    }
  }

  // A Queueable cannot also be Schedulable, so the nightly trigger is a separate type.
  public class Nightly implements Schedulable {
    public void execute(SchedulableContext context) {
      enqueuer.enqueue(new ADA_MetadataIndexJob());
    }
  }

  public class IndexJobException extends Exception {
  }

  @TestVisible
  private static Enqueuer enqueuer = new SystemEnqueuer();
  // Callouts one Queueable may spend on metadata fetches. The platform allows 100 per
  // transaction; the rest is headroom for the list queries of the discovery run.
  @TestVisible
  private static Integer chunkBudget = 80;

  private final Boolean discovered;
  private final List<ADA_MetadataIndexer.WorkItem> pending;

  public ADA_MetadataIndexJob() {
    this.discovered = false;
    this.pending = new List<ADA_MetadataIndexer.WorkItem>();
  }

  @TestVisible
  private ADA_MetadataIndexJob(List<ADA_MetadataIndexer.WorkItem> pending) {
    this.discovered = true;
    this.pending = pending;
  }

  public static Id runNow() {
    requireAccess();
    return enqueuer.enqueue(new ADA_MetadataIndexJob());
  }

  public static Id schedule() {
    requireAccess();
    for (CronTrigger existing : [
      SELECT Id
      FROM CronTrigger
      WHERE CronJobDetail.Name = :SCHEDULE_NAME
    ]) {
      System.abortJob(existing.Id);
    }
    return System.schedule(SCHEDULE_NAME, NIGHTLY_CRON, new Nightly());
  }

  public void execute(QueueableContext context) {
    ADA_MetadataIndexer indexer = new ADA_MetadataIndexer();
    List<ADA_MetadataIndexer.WorkItem> next;
    if (!discovered) {
      // Discovery ends with DML, so the first metadata callouts wait for the next run.
      next = indexer.discover();
    } else {
      Integer room = Limits.getLimitCallouts() - Limits.getCallouts();
      next = indexer.runChunk(pending, Math.min(chunkBudget, room));
    }
    if (!next.isEmpty()) {
      enqueuer.enqueue(new ADA_MetadataIndexJob(next));
    }
  }

  @TestVisible
  private Boolean isDiscovered() {
    return discovered;
  }

  @TestVisible
  private Integer pendingCount() {
    return pending.size();
  }

  private static void requireAccess() {
    if (
      !Schema.sObjectType.ADA_Metadata_Index__c.isCreateable() ||
      !Schema.sObjectType.ADA_Metadata_Index__c.isUpdateable() ||
      !Schema.sObjectType.ADA_Metadata_Index__c.isDeletable()
    ) {
      throw new IndexJobException(
        'Only an ADA administrator can run the metadata index.'
      );
    }
  }
}
