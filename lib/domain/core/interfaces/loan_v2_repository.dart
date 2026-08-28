import '../../../utils/network/data_state.dart';

abstract class LoanV2Repository {
  Future<DataState<Map<String, dynamic>>> eligibility();
  Future<DataState<List<dynamic>>> products();
  Future<DataState<Map<String, dynamic>>> previewApplication(
      int productId, int requestedAmount, int tenorMonths);
  Future<DataState<Map<String, dynamic>>> createApplication(
      Map<String, dynamic> body);
  Future<DataState<Map<String, dynamic>>> updateApplication(
      int id, Map<String, dynamic> body);
  Future<DataState<Map<String, dynamic>>> application(int id);
  Future<DataState<Map<String, dynamic>>> applications(
      {int page = 1, int size = 20});
  Future<DataState<List<dynamic>>> guarantorCandidates(int applicationId,
      {String search = ''});
  Future<DataState<List<dynamic>>> selectGuarantors(
      int applicationId, List<int> customerIds);
  Future<DataState<Map<String, dynamic>>> uploadBorrowerFace(
      int applicationId, String path);
  Future<DataState<Map<String, dynamic>>> createBorrowerVerification(
      int applicationId, Map<String, dynamic> body);
  Future<DataState<Map<String, dynamic>>> createLivenessChallenge(
      int applicationId);
  Future<DataState<Map<String, dynamic>>> uploadLivenessEvidence(
      int applicationId, int sessionId, String nonce, String path);
  Future<DataState<Map<String, dynamic>>> livenessStatus(int applicationId);
  Future<DataState<Map<String, dynamic>>> uploadSignature(
      int applicationId, String documentType, String path);
  Future<DataState<Map<String, dynamic>>> signApplication(
      int applicationId, Map<String, dynamic> body);
  Future<DataState<Map<String, dynamic>>> signFinalAgreement(
      int applicationId, Map<String, dynamic> body);
  Future<DataState<Map<String, dynamic>>> submit(
      int applicationId, int rowVersion);
  Future<DataState<List<dynamic>>> timeline(int applicationId);
  Future<DataState<List<dynamic>>> installments(int applicationId);
  Future<DataState<void>> cancel(int applicationId, String reason);
}
