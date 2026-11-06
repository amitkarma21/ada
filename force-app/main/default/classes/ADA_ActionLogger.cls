public with sharing class ADA_ActionLogger {
  public static final Integer MAX_PAYLOAD = 131072;
  public static final Integer MAX_RESULT = 4000;

  public class LogException extends Exception {
  }

  public class Entry {
    public String sessionKey;
    public String step;
    public String errorType;
    public String componentApiName;
    public String objectApiName;
    public Decimal confidence;
    public String targetSystem = 'None';
    public String payloadSent;
    public String result;
    public String externalId;
    public String externalUrl;
    public String status = 'Success';
    public String idempotencyKey;
    public String feedback;
  }

  // The only writer of ADA_Action_Log__c. Users have no create permission on the log,
  // so every audit row comes through here and is owned by the user who triggered it.
  public static ADA_Action_Log__c write(Entry entry) {
    if (entry == null || String.isBlank(entry.step)) {
      throw new LogException('A log row needs a step.');
    }
    return new Writer().write(entry);
  }

  // The caller's own successful row for this key, or null. Failed rows never count, so a
  // failed send can be tried again.
  public static ADA_Action_Log__c findSuccess(String idempotencyKey) {
    if (String.isBlank(idempotencyKey)) {
      return null;
    }
    return new Reader().find(idempotencyKey);
  }

  private without sharing class Reader {
    public ADA_Action_Log__c find(String idempotencyKey) {
      List<ADA_Action_Log__c> rows = [
        SELECT Id, External_Id__c, External_Url__c, Result__c
        FROM ADA_Action_Log__c
        WHERE
          Idempotency_Key__c = :idempotencyKey
          AND OwnerId = :UserInfo.getUserId()
          AND Status__c = 'Success'
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      return rows.isEmpty() ? null : rows[0];
    }
  }

  private without sharing class Writer {
    public ADA_Action_Log__c write(Entry entry) {
      if (String.isNotBlank(entry.idempotencyKey)) {
        List<ADA_Action_Log__c> existing = [
          SELECT Id
          FROM ADA_Action_Log__c
          WHERE
            Idempotency_Key__c = :entry.idempotencyKey
            AND OwnerId = :UserInfo.getUserId()
          WITH SYSTEM_MODE
          LIMIT 1
        ];
        if (!existing.isEmpty()) {
          return existing[0];
        }
      }
      ADA_Action_Log__c row = new ADA_Action_Log__c(
        Session_Key__c = entry.sessionKey,
        Step__c = entry.step,
        Error_Type__c = entry.errorType,
        Component_Api_Name__c = entry.componentApiName,
        Object_Api_Name__c = entry.objectApiName,
        Confidence__c = entry.confidence,
        Target_System__c = entry.targetSystem,
        Payload_Sent__c = clip(entry.payloadSent, MAX_PAYLOAD),
        Result__c = clip(entry.result, MAX_RESULT),
        External_Id__c = entry.externalId,
        External_Url__c = entry.externalUrl,
        Status__c = entry.status,
        Idempotency_Key__c = entry.idempotencyKey,
        Feedback__c = entry.feedback
      );
      Database.insert(row, true, AccessLevel.SYSTEM_MODE);
      return row;
    }
  }

  private static String clip(String text, Integer max) {
    return text == null || text.length() <= max ? text : text.left(max);
  }
}
