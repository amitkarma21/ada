public interface ADA_ILlmProvider {
  ADA_Explanation explain(
    ADA_Diagnosis diagnosis,
    ADA_PayloadBuilder.Extras extras
  );
  String lastPayload();
}
