import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/transfer_task.dart';
import '../bloc/transfer_bloc.dart';
import '../bloc/transfer_event.dart';
import '../bloc/transfer_state.dart';
import '../widgets/section_header.dart';
import '../widgets/status_panel.dart';
import '../widgets/transfer_item_tile.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? _selectedFilePath;
  String? _selectedFileName;
  int? _selectedFileSize;
  bool _isGeneratingSample = false;

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.any,
      );

      if (file != null && file.path != null) {
        setState(() {
          _selectedFilePath = file.path;
          _selectedFileName = file.name;
          _selectedFileSize = file.lengthSync();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _generateSample50MbFile() async {
    setState(() => _isGeneratingSample = true);
    try {
      final tempDir = Directory.systemTemp;
      final sampleFile = File('${tempDir.path}/catalog_sample_50mb.csv');
      final sink = sampleFile.openWrite();
      sink.writeln('id,sku,name,price,inventory_count,description,category');

      const row =
          '1001,SKU-PROD-001,Wireless Barcode Scanner,129.99,450,High speed 2D barcode scanner with Bluetooth for retail POS stations,Hardware\n';
      const targetBytes = 52428800; // 50MB
      final iterations = targetBytes ~/ row.length;
      for (int i = 0; i < iterations; i++) {
        sink.write(row);
      }
      await sink.flush();
      await sink.close();

      final actualSize = await sampleFile.length();
      setState(() {
        _selectedFilePath = sampleFile.path;
        _selectedFileName = 'catalog_sample_50mb.csv';
        _selectedFileSize = actualSize;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generated 50MB catalog CSV for testing'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating sample file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSample = false);
      }
    }
  }

  void _startUpload() {
    if (_selectedFilePath == null || _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or generate a file first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.read<TransferBloc>().add(
          TransferUploadRequested(
            filePath: _selectedFilePath!,
            fileName: _selectedFileName!,
          ),
        );

    setState(() {
      _selectedFilePath = null;
      _selectedFileName = null;
      _selectedFileSize = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Upload started — keeps running if you leave this screen'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedFilePath = null;
      _selectedFileName = null;
      _selectedFileSize = null;
    });
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double b = bytes.toDouble();
    while (b >= 1024 && i < suffixes.length - 1) {
      b /= 1024;
      i++;
    }
    return '${b.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import catalog'),
      ),
      body: BlocBuilder<TransferBloc, TransferState>(
        builder: (context, state) {
          final uploadTasks = state.allTasks
              .where((t) => t.type == TransferType.upload)
              .toList();
          final activeCount = uploadTasks
              .where((t) => t.isRunning || t.isPaused || t.status == TransferStatus.queued)
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              if (activeCount > 0) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sync_rounded,
                        size: 18,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$activeCount active ${activeCount == 1 ? 'transfer' : 'transfers'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Upload file to POS server',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CSV catalogs, images, or large media files',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dashed pick zone
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _pickFile,
                          borderRadius: BorderRadius.circular(14),
                          child: CustomPaint(
                            painter: _DashedRRectPainter(
                              color: colorScheme.primary.withValues(alpha: 0.55),
                              radius: 14,
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 28,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.upload_file_rounded,
                                    size: 36,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _selectedFileName == null
                                        ? 'Pick a CSV, image, or video'
                                        : 'Tap to change file',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to browse device storage',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_selectedFileName != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.insert_drive_file_outlined,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedFileName!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _formatSize(_selectedFileSize ?? 0),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Clear selection',
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: _clearSelection,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isGeneratingSample
                                  ? null
                                  : _generateSample50MbFile,
                              icon: _isGeneratingSample
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.auto_awesome,
                                      color: AppColors.primary,
                                    ),
                              label: const Text('>50MB Sample'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _selectedFileName == null
                                  ? null
                                  : _startUpload,
                              icon: const Icon(Icons.upload_rounded),
                              label: const Text('Start upload'),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Keeps running if you leave this screen.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              SectionHeader(
                title: 'Upload history & queue',
                count: uploadTasks.length,
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
              ),

              if (uploadTasks.isEmpty)
                const StatusPanel(
                  icon: Icons.cloud_upload_outlined,
                  title: 'No uploads yet',
                  message:
                      'Pick a file or generate a 50MB sample to begin importing.',
                  padding: EdgeInsets.fromLTRB(0, 8, 0, 16),
                )
              else
                ...uploadTasks.map(
                  (task) => TransferItemTile(
                    task: task,
                    onPause: () => context.read<TransferBloc>().add(
                          TransferPauseRequested(task.id),
                        ),
                    onResume: () => context.read<TransferBloc>().add(
                          TransferResumeRequested(task.id),
                        ),
                    onCancel: () => context.read<TransferBloc>().add(
                          TransferCancelRequested(task.id),
                        ),
                    onRetry: () => context.read<TransferBloc>().add(
                          TransferRetryRequested(task.id),
                        ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  static const double _strokeWidth = 1.5;
  static const double _dashWidth = 6;
  static const double _dashGap = 4;

  _DashedRRectPainter({
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        _strokeWidth / 2,
        _strokeWidth / 2,
        size.width - _strokeWidth,
        size.height - _strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + _dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
