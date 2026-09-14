const _loanV2StatusLabels = <String, String>{
  'DRAFT': 'Draf',
  'BORROWER_VERIFICATION_PENDING': 'Menunggu Verifikasi Peminjam',
  'WAITING_GUARANTOR_CONFIRMATION': 'Menunggu Konfirmasi Penjamin',
  'NEEDS_GUARANTOR_REPLACEMENT': 'Perlu Ganti Penjamin',
  'PENDING_ADMIN_REVIEW': 'Menunggu Tinjauan Admin',
  'WAITING_INTERVIEW': 'Menunggu Wawancara',
  'INTERVIEW_COMPLETED': 'Siap Ditinjau Admin',
  'APPROVED_AWAITING_FINAL_SIGNATURES': 'Disetujui, Menunggu TTD Perjanjian',
  'AWAITING_DISBURSEMENT': 'Menunggu Pencairan',
  'DISBURSED': 'Sudah Dicairkan',
  'COMPLETED': 'Selesai',
  'REJECTED': 'Ditolak',
  'CANCELLED': 'Dibatalkan',
  'EXPIRED': 'Kedaluwarsa',
  'SELECTED': 'Dipilih',
  'INVITED': 'Menunggu Konfirmasi',
  'VERIFICATION_PENDING': 'Menunggu Verifikasi Penjamin',
  'CONFIRMED': 'Disetujui Penjamin',
  'REVOKED': 'Dicabut',
  'PENDING': 'Menunggu Proses',
  'PROCESSING': 'Sedang Diproses',
  'DELIVERED': 'Terkirim',
  'OPENED': 'Sudah Dibuka',
  'CONSUMED': 'Sudah Digunakan',
  'DELIVERY_FAILED': 'Pengiriman Gagal',
  'CREATED': 'Dibuat',
  'SUBMITTED': 'Dikirim',
  'VERIFIED': 'Terverifikasi',
  'FAILED': 'Gagal',
  'GENERATING': 'Dokumen Sedang Dibuat',
  'GENERATED': 'Dokumen Dibuat',
  'READY': 'Dokumen Siap',
  'SIGNING': 'Menunggu TTD',
  'SIGNED': 'Sudah Ditandatangani',
  'SUPERSEDED': 'Digantikan',
  'STAMPED': 'Meterai Terpasang',
  'SCHEDULED': 'Dijadwalkan',
  'AWAITING_PAYMENT': 'Menunggu Pembayaran',
  'PARTIALLY_PAID': 'Dibayar Sebagian',
  'PAID': 'Lunas',
  'WAIVED': 'Dibebaskan',
  'DUE': 'Jatuh Tempo',
  'OVERDUE': 'Terlambat',
  'SUCCEEDED': 'Berhasil',
  'REFUNDED': 'Dikembalikan',
  'UPLOADED': 'Diunggah',
  'ATTACHED': 'Terpasang',
  'PURGE_PENDING': 'Menunggu Penghapusan',
  'PURGED': 'Sudah Dihapus',
  'PURGE_FAILED': 'Penghapusan Gagal',
  'IN_PROGRESS': 'Sedang Berlangsung',
  'NO_SHOW': 'Tidak Hadir',
  'RECOMMENDED': 'Direkomendasikan',
  'NOT_RECOMMENDED': 'Tidak Direkomendasikan',
  'SENT': 'Terkirim',
};

String loanV2StatusLabel(String? status) {
  final value = status?.trim() ?? '';
  if (value.isEmpty) return '-';
  final label = _loanV2StatusLabels[value];
  if (label != null) return label;

  return value
      .toLowerCase()
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
