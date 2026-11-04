public with sharing class ADA_EmailTarget implements ADA_IActionTarget {
  public static final String NAME = 'Email';
  private static final Integer MAX_SUBJECT = 200;
  private static final Integer MAX_ADDRESS = 254;
  private static final Pattern MAILBOX = Pattern.compile(
    '[A-Za-z0-9._%+\\-]+@[A-Za-z0-9\\-]+(?:\\.[A-Za-z0-9\\-]+)*\\.[A-Za-z]{2,}'
  );

  public interface Sender {
    String deliver(Messaging.SingleEmailMessage message);
  }

  @TestVisible
  private static Sender sender = new SalesforceSender();

  private final ADA_Setting__mdt setting;

  public ADA_EmailTarget() {
    this(ADA_Setting__mdt.getInstance('Default'));
  }

  public ADA_EmailTarget(ADA_Setting__mdt setting) {
    this.setting = setting;
  }

  public String targetName() {
    return NAME;
  }

  public ADA_ActionResult submit(String idempotencyKey, String payloadJson) {
    String address = recipient();
    if (address == null) {
      return fail(
        'Bug reports by email are not set up. Ask your admin to set the bug report address in the ADA settings.'
      );
    }
    if (String.isBlank(idempotencyKey)) {
      return fail('This request has no idempotency key, so it was not sent.');
    }
    ADA_PayloadBuilder.WorkItemBody body = parse(payloadJson);
    if (body == null) {
      return fail('The report was not valid, so nothing was sent.');
    }
    Messaging.SingleEmailMessage message = build(address, body);
    Set<String> kinds = ADA_PiiGate.detect(
      message.getSubject() + '\n' + message.getPlainTextBody()
    );
    if (!kinds.isEmpty()) {
      return ADA_ActionResult.blocked(
        NAME,
        'The report was not sent because it contains personal data (' +
          String.join(new List<String>(kinds), ', ') +
          '). Remove it from your notes and try again.'
      );
    }
    return deliver(message);
  }

  private ADA_ActionResult deliver(Messaging.SingleEmailMessage message) {
    String code;
    try {
      code = sender.deliver(message);
    } catch (EmailException refused) {
      code = String.valueOf(refused.getMessage()).contains('LIMIT_EXCEEDED')
        ? 'SINGLE_EMAIL_LIMIT_EXCEEDED'
        : 'EMAIL_EXCEPTION';
    }
    if (code == null) {
      return ADA_ActionResult.ok(
        NAME,
        'Your admin team was emailed the report. You do not need to send it again.'
      );
    }
    if (code == 'SINGLE_EMAIL_LIMIT_EXCEEDED') {
      return fail(
        'ADA has reached the daily email limit, so the report was not sent. Try again tomorrow or tell your admin.'
      );
    }
    if (code == 'INVALID_EMAIL_ADDRESS') {
      return fail(
        'The bug report address in the ADA settings is not accepted. Ask your admin to check it.'
      );
    }
    return fail(
      'The email could not be sent (' +
        code +
        '). Ask your admin to check email deliverability.'
    );
  }

  private static Messaging.SingleEmailMessage build(
    String address,
    ADA_PayloadBuilder.WorkItemBody body
  ) {
    Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
    message.setToAddresses(new List<String>{ address });
    message.setSubject(oneLine(body.title).abbreviate(MAX_SUBJECT));
    message.setPlainTextBody(
      body.description + '\n\nTags: ' + oneLine(body.tags)
    );
    message.setSaveAsActivity(false);
    message.setUseSignature(false);
    return message;
  }

  private String recipient() {
    if (setting == null || String.isBlank(setting.Bug_Report_Email__c)) {
      return null;
    }
    String address = setting.Bug_Report_Email__c.trim();
    return address.length() <= MAX_ADDRESS && MAILBOX.matcher(address).matches()
      ? address
      : null;
  }

  private static String oneLine(String text) {
    return text.replaceAll('[\\r\\n]+', ' ').trim();
  }

  private static ADA_PayloadBuilder.WorkItemBody parse(String payloadJson) {
    if (String.isBlank(payloadJson)) {
      return null;
    }
    try {
      ADA_PayloadBuilder.WorkItemBody body = (ADA_PayloadBuilder.WorkItemBody) JSON.deserialize(
        payloadJson,
        ADA_PayloadBuilder.WorkItemBody.class
      );
      if (
        body == null ||
        String.isBlank(body.title) ||
        String.isBlank(body.description) ||
        String.isBlank(body.tags)
      ) {
        return null;
      }
      return body;
    } catch (Exception broken) {
      return null;
    }
  }

  private static ADA_ActionResult fail(String message) {
    return ADA_ActionResult.failed(NAME, message);
  }

  private class SalesforceSender implements Sender {
    public String deliver(Messaging.SingleEmailMessage message) {
      List<Messaging.SendEmailResult> results = Messaging.sendEmail(
        new List<Messaging.SingleEmailMessage>{ message },
        false
      );
      if (results[0].isSuccess()) {
        return null;
      }
      return String.valueOf(results[0].getErrors()[0].getStatusCode());
    }
  }
}
