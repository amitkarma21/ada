@IsTest
private class ADA_MetadataIndexJobTest {
  private class Recorder implements ADA_MetadataIndexJob.Enqueuer {
    public List<Queueable> jobs = new List<Queueable>();

    public Id enqueue(Queueable job) {
      jobs.add(job);
      return null;
    }
  }

  @TestSetup
  static void setup() {
    ADA_IndexTestSupport.createUser('jobadm', 'ADA_Admin');
    ADA_IndexTestSupport.createUser('jobusr', 'ADA_User');
    ADA_IndexTestSupport.seedIndex();
  }

  // Test.startTest() commits the set-up data, which a callout would otherwise reject.
  private static User byAlias(String alias) {
    Test.startTest();
    return [SELECT Id FROM User WHERE Alias = :alias LIMIT 1];
  }

  private static Recorder record() {
    Recorder recorder = new Recorder();
    ADA_MetadataIndexJob.enqueuer = recorder;
    return recorder;
  }

  @IsTest
  static void runNowQueuesAFreshDiscoveryJob() {
    Recorder recorder = record();
    System.runAs(byAlias('jobadm')) {
      ADA_MetadataIndexJob.runNow();
    }
    Assert.areEqual(1, recorder.jobs.size());
    Assert.isFalse(((ADA_MetadataIndexJob) recorder.jobs[0]).isDiscovered());
  }

  @IsTest
  static void aPlainUserCannotRunOrScheduleTheIndex() {
    Recorder recorder = record();
    System.runAs(byAlias('jobusr')) {
      try {
        ADA_MetadataIndexJob.runNow();
        Assert.fail('Expected an IndexJobException');
      } catch (ADA_MetadataIndexJob.IndexJobException e) {
        Assert.isTrue(e.getMessage().contains('administrator'));
      }
      try {
        ADA_MetadataIndexJob.schedule();
        Assert.fail('Expected an IndexJobException');
      } catch (ADA_MetadataIndexJob.IndexJobException e) {
        Assert.isNotNull(e.getMessage());
      }
    }
    Assert.isTrue(recorder.jobs.isEmpty());
  }

  @IsTest
  static void scheduleCreatesOneNightlyTriggerEvenWhenCalledTwice() {
    System.runAs(byAlias('jobadm')) {
      ADA_MetadataIndexJob.schedule();
      ADA_MetadataIndexJob.schedule();
      Test.stopTest();
    }
    List<CronTrigger> triggers = [
      SELECT CronExpression
      FROM CronTrigger
      WHERE CronJobDetail.Name = :ADA_MetadataIndexJob.SCHEDULE_NAME
    ];
    Assert.areEqual(1, triggers.size());
    Assert.areEqual(
      ADA_MetadataIndexJob.NIGHTLY_CRON,
      triggers[0].CronExpression
    );
  }

  @IsTest
  static void theScheduledRunQueuesADiscoveryJob() {
    Recorder recorder = record();
    new ADA_MetadataIndexJob.Nightly().execute(null);
    Assert.areEqual(1, recorder.jobs.size());
  }

  @IsTest
  static void discoveryQueuesTheChangedItemsForTheNextRun() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    Recorder recorder = record();
    for (Integer i = 0; i < 3; i++) {
      router.rules.add(
        ADA_IndexTestSupport.rule(
          ADA_IndexTestSupport.fakeId(i),
          'New_Rule_' + i,
          'Opportunity',
          ADA_IndexTestSupport.NEWER_DATE
        )
      );
    }
    System.runAs(byAlias('jobadm')) {
      new ADA_MetadataIndexJob().execute((QueueableContext) null);
    }
    Assert.areEqual(0, router.metadataCalls);
    Assert.areEqual(1, recorder.jobs.size());
    ADA_MetadataIndexJob next = (ADA_MetadataIndexJob) recorder.jobs[0];
    Assert.isTrue(next.isDiscovered());
    Assert.areEqual(3, next.pendingCount());
  }

  @IsTest
  static void aRunWithNothingChangedMakesNoMetadataCalls() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    Recorder recorder = record();
    router.rules.add(
      ADA_IndexTestSupport.rule(
        ADA_IndexTestSupport.fakeId(1),
        'Rule_Same',
        'Case',
        ADA_IndexTestSupport.SAME_DATE
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
    System.runAs(byAlias('jobadm')) {
      new ADA_MetadataIndexJob().execute((QueueableContext) null);
    }
    Assert.areEqual(0, router.metadataCalls);
    Assert.isTrue(recorder.jobs.isEmpty());
  }

  @IsTest
  static void aBigBacklogIsProcessedInChunksThatChainOn() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    Recorder recorder = record();
    ADA_MetadataIndexJob.chunkBudget = 70;
    System.runAs(byAlias('jobadm')) {
      Integer before = Limits.getCallouts();
      new ADA_MetadataIndexJob(ADA_IndexTestSupport.ruleItems(150))
        .execute((QueueableContext) null);
      Assert.isTrue(Limits.getCallouts() - before <= 70);
    }
    Assert.areEqual(70, router.metadataCalls);
    Assert.areEqual(1, recorder.jobs.size());
    Assert.areEqual(
      80,
      ((ADA_MetadataIndexJob) recorder.jobs[0]).pendingCount()
    );
  }

  @IsTest
  static void theLastChunkDoesNotChainAgain() {
    ADA_IndexTestSupport.Router router = ADA_IndexTestSupport.install();
    Recorder recorder = record();
    System.runAs(byAlias('jobadm')) {
      new ADA_MetadataIndexJob(ADA_IndexTestSupport.ruleItems(10))
        .execute((QueueableContext) null);
    }
    Assert.areEqual(10, router.metadataCalls);
    Assert.isTrue(recorder.jobs.isEmpty());
  }
}
