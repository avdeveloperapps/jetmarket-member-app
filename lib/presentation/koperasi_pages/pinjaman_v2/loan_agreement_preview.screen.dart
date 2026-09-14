import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jetmarket/infrastructure/theme/app_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class LoanAgreementPreviewScreen extends StatelessWidget {
  const LoanAgreementPreviewScreen({
    super.key,
    required this.file,
    required this.title,
  });

  final File file;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title, style: text16BlackSemiBold),
          actions: [
            IconButton(
              tooltip: 'Simpan atau bagikan',
              onPressed: () => Share.shareXFiles(
                [XFile(file.path, mimeType: 'application/pdf')],
                subject: title,
              ),
              icon: const Icon(Icons.ios_share_rounded),
            )
          ],
        ),
        body: SfPdfViewer.file(file),
      );
}
