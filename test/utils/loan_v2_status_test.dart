import 'package:flutter_test/flutter_test.dart';
import 'package:jetmarket/utils/loan_v2_status.dart';

void main() {
  test('translates loan application statuses into concise Indonesian labels',
      () {
    expect(loanV2StatusLabel('DRAFT'), 'Draf');
    expect(loanV2StatusLabel('WAITING_GUARANTOR_CONFIRMATION'),
        'Menunggu Konfirmasi Penjamin');
    expect(loanV2StatusLabel('APPROVED_AWAITING_FINAL_SIGNATURES'),
        'Disetujui, Menunggu TTD Perjanjian');
    expect(loanV2StatusLabel('VERIFICATION_PENDING'),
        'Menunggu Verifikasi Penjamin');
    expect(loanV2StatusLabel('PARTIALLY_PAID'), 'Dibayar Sebagian');
  });

  test('uses a readable fallback for an unknown status', () {
    expect(loanV2StatusLabel('CUSTOM_REVIEW_PENDING'),
        'Custom Review Pending');
  });
}
